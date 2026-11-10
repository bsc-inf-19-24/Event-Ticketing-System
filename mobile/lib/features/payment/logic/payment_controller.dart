import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../features/auth/logic/auth_controller.dart';
import '../../../features/orders/models/order.dart';
import '../../../features/orders/order_rules.dart';
import '../../../features/orders/services/order_repository.dart';
import '../../../features/tickets/logic/tickets_controller.dart';
import '../../../models/event.dart';
import '../../../models/ticket.dart';
import '../models/payment_models.dart';
import '../services/api_payment_service.dart';
import '../services/fake_payment_service.dart';
import '../services/payment_service.dart';
import 'payment_verifier.dart';

/// Coordinates order creation, payment verification, and ticket persistence.
class PaymentController extends ChangeNotifier {
  PaymentController({
    PaymentService? paymentService,
    OrderRepository? orderRepository,
    TicketsController? ticketsController,
    AuthController? auth,
    Random? random,
  }) : _paymentService = paymentService ?? paymentServiceGlobal,
       _orderRepository = orderRepository ?? OrderRepository(),
       _ticketsController = ticketsController ?? ticketsControllerGlobal,
       _auth = auth ?? authController,
       _random = random ?? Random();

  final PaymentService _paymentService;
  final OrderRepository _orderRepository;
  final TicketsController _ticketsController;
  final AuthController _auth;
  final Random _random;
  Order? order;
  CheckoutSession? checkoutSession;
  bool isProcessing = false;
  String? failureReason;
  List<Ticket> purchasedTickets = const [];
  String _buyerName = '';
  String _buyerEmail = '';
  String? _pendingIdempotencyKey;
  String? _pendingOrderFingerprint;
  bool _beginInFlight = false;
  bool _pendingVerification = false;
  bool get isPendingVerification => _pendingVerification;
  static const pendingOrderPreference = 'pending_payment_order_id';
  String? _paymentState;
  String? get paymentState => _paymentState;

  /// Creates an order and starts the selected test or backend payment flow.
  Future<void> begin({
    required Event event,
    required List<OrderItem> items,
    required int total,
    required PaymentMethod method,
    required String phone,
  }) async {
    if (_beginInFlight || isProcessing) return;
    if (!hasValidTicketSelection(items)) {
      throw const PaymentException(
        'Choose between 1 and 10 tickets, without duplicate ticket types.',
      );
    }
    final user = _auth.user;
    if (user == null) {
      throw const PaymentException('Please log in to continue.');
    }

    _beginInFlight = true;
    isProcessing = true;
    failureReason = null;
    _pendingVerification = false;
    _paymentState = null;
    checkoutSession = null;
    purchasedTickets = const [];
    _buyerName = user.name;
    _buyerEmail = user.email;
    notifyListeners();

    final now = DateTime.now();
    final randomDigits = _random.nextInt(10000).toString().padLeft(4, '0');
    final service = _paymentService;
    try {
      if (service is ApiPaymentService) {
        await _beginServerCheckout(
          service,
          event: event,
          item: items.single,
          method: method,
          userId: _auth.stableUserId!,
          now: now,
          randomDigits: randomDigits,
        );
        return;
      }

      final txRef = 'TM-${now.millisecondsSinceEpoch}-$randomDigits';
      final createdOrder = Order(
        id: 'ORD-${now.millisecondsSinceEpoch}-$randomDigits',
        userId: _auth.stableUserId!,
        eventTitle: event.title,
        eventVenue: event.venue,
        eventDate: event.date,
        items: items,
        total: total,
        status: 'pending',
        txRef: txRef,
        paymentMethod: method.name,
        createdAt: now,
      );
      await _orderRepository.saveOrder(createdOrder);
      order = createdOrder;
      final names = user.name.trim().split(RegExp(r'\s+'));
      checkoutSession = await service.initiateCheckout(
        PaymentRequest(
          amount: total,
          email: user.email,
          firstName: names.first,
          lastName: names.length > 1 ? names.skip(1).join(' ') : '',
          txRef: txRef,
          mobile: method == PaymentMethod.card || phone.isEmpty ? null : phone,
          meta: {'order_id': createdOrder.id},
        ),
      );
      if (checkoutSession!.checkoutUrl.isEmpty ||
          checkoutSession!.txRef != txRef) {
        throw const PaymentException(
          'The payment provider returned an invalid checkout session.',
        );
      }
    } catch (error) {
      if (order != null && service is! ApiPaymentService) {
        await _orderRepository.updateOrderStatus(order!.id, 'failed');
      }
      rethrow;
    } finally {
      _beginInFlight = false;
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _beginServerCheckout(
    ApiPaymentService service, {
    required Event event,
    required OrderItem item,
    required PaymentMethod method,
    required String userId,
    required DateTime now,
    required String randomDigits,
  }) async {
    final eventId = event.id;
    final ticketTypeId = item.ticketTypeId;
    if (eventId == null ||
        eventId.isEmpty ||
        ticketTypeId == null ||
        ticketTypeId.isEmpty) {
      throw const PaymentException(
        'This event is missing its server event or ticket-type ID. Refresh the event list before buying.',
      );
    }

    final fingerprint = '$eventId:$ticketTypeId:${item.quantity}';
    if (_pendingOrderFingerprint != fingerprint) {
      _pendingOrderFingerprint = fingerprint;
      _pendingIdempotencyKey =
          'order-${now.millisecondsSinceEpoch}-$randomDigits';
    }
    final response = await service.createOrder(
      eventId: eventId,
      items: [item],
      idempotencyKey: _pendingIdempotencyKey!,
    );
    final orderId = _firstString([
      response['id'],
      response['orderId'],
      response['order_id'],
    ]);
    final serverTotal = _integer([
      response['totalAmount'],
      response['total_amount'],
      response['total'],
    ]);
    if (orderId.isEmpty || serverTotal <= 0) {
      throw const PaymentException(
        'The server order response is missing its ID or total.',
      );
    }

    final serverItems = _parseOrderItems(response['items']);
    final createdOrder = Order(
      id: orderId,
      userId: userId,
      eventTitle: event.title,
      eventVenue: event.venue,
      eventDate: event.date,
      items: serverItems.isEmpty ? [item] : serverItems,
      total: serverTotal,
      status: _firstString([response['status']], fallback: 'pending'),
      txRef: '',
      paymentMethod: method.name,
      createdAt: now,
    );
    order = createdOrder;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(pendingOrderPreference, orderId);
    await _orderRepository.saveOrder(createdOrder);

    final session = await service.initiateOrderPayment(
      orderId: orderId,
      method: method,
      phone: '',
    );
    if (session.amount > 0 && session.amount != serverTotal) {
      throw const PaymentException(
        'The checkout amount does not match the server order amount.',
      );
    }
    checkoutSession = session;
    order = createdOrder.copyWith(txRef: session.txRef);
    await _orderRepository.saveOrder(order!);
  }

  /// Completes a payment only after the configured service confirms it.
  Future<bool> verifyPendingOrder(Event event) =>
      finish(event, PaymentOutcome.success);

  Future<bool> finish(
    Event event,
    PaymentOutcome outcome, {
    String? failureMessage,
  }) async {
    final currentOrder = order;
    if (currentOrder == null) {
      failureReason = 'The order could not be found.';
      return false;
    }
    if (_paymentService is ApiPaymentService &&
        outcome == PaymentOutcome.cancelled) {
      failureReason = 'Payment is still pending. Verify it when you return.';
      _pendingVerification = true;
      _paymentState = 'pending';
      notifyListeners();
      return false;
    }
    isProcessing = true;
    failureReason = null;
    notifyListeners();
    try {
      final service = _paymentService;
      if (service is ApiPaymentService) {
        final success = await _finishServerOrder(service, currentOrder);
        if (success) _clearIdempotencyState();
        return success;
      }
      service.completePayment(currentOrder.txRef, outcome);
      if (outcome == PaymentOutcome.cancelled) {
        failureReason = failureMessage ?? 'Payment was cancelled.';
        await _updateOrderStatus(
          currentOrder.id,
          'cancelled',
          'Payment was cancelled, but we could not update the order.',
        );
        return false;
      }

      PaymentVerification? verification;
      for (var attempt = 0; attempt < 3; attempt++) {
        verification = await service.verifyPayment(currentOrder.txRef);
        if (verification.status != 'pending') break;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (verification == null ||
          !isPaymentVerified(
            verification,
            expectedTxRef: currentOrder.txRef,
            expectedAmount: currentOrder.total,
          )) {
        failureReason = failureMessage ?? 'Payment could not be verified.';
        await _updateOrderStatus(
          currentOrder.id,
          'failed',
          'Payment could not be verified or saved. Please contact support.',
        );
        return false;
      }
      purchasedTickets = await _orderRepository.completePaidOrder(
        order: currentOrder,
        event: event,
        ticketsController: _ticketsController,
        buyerName: _buyerName,
        buyerEmail: _buyerEmail,
      );
      return true;
    } catch (error) {
      failureReason = error is ApiException
          ? error.message
          : error is PaymentException
          ? error.message
          : 'We could not verify your payment. Please try again.';
      if (_paymentService is! ApiPaymentService) {
        await _updateOrderStatus(
          currentOrder.id,
          'failed',
          'We could not verify or save your payment. Please contact support.',
        );
      }
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> _finishServerOrder(
    ApiPaymentService service,
    Order currentOrder,
  ) async {
    final verification = await service.verifyOrder(currentOrder.id);
    final preferences = await SharedPreferences.getInstance();
    final remoteOrder = _nestedMap(verification['order']);
    final payment = _nestedMap(verification['payment']);
    final status = _firstString([
      remoteOrder['status'],
      verification['orderStatus'],
      verification['order_status'],
      verification['status'],
    ]).toUpperCase();
    final paymentStatus = _firstString([
      verification['paymentStatus'],
      verification['payment_status'],
      payment['status'],
      verification['status'],
    ]).toUpperCase();
    if (status == 'PAID' && paymentStatus == 'PAID') {
      purchasedTickets = await _readIssuedTickets(
        service,
        remoteOrder,
        currentOrder,
      );
      if (purchasedTickets.isEmpty) {
        throw const ApiException(
          'Payment is confirmed, but the server has not returned the issued tickets yet.',
        );
      }
      await preferences.remove(pendingOrderPreference);
      return true;
    }
    if (status == 'FAILED' || paymentStatus == 'FAILED') {
      _paymentState = 'failed';
      _pendingVerification = false;
      await preferences.remove(pendingOrderPreference);
      failureReason = 'The server could not confirm this payment.';
      return false;
    }
    _paymentState = 'pending';
    _pendingVerification = true;
    await preferences.setString(pendingOrderPreference, currentOrder.id);
    failureReason = 'Payment is still pending. Recheck when ready.';
    return false;
  }

  Future<List<Ticket>> _readIssuedTickets(
    ApiPaymentService service,
    Map<String, dynamic> orderResponse,
    Order currentOrder,
  ) async {
    var values = _ticketValues(orderResponse);
    if (values.isEmpty) values = await service.getOrderTickets(currentOrder.id);
    final userId = _auth.stableUserId ?? currentOrder.userId;
    if (userId.isEmpty) {
      throw const ApiException(
        'The signed-in customer could not be matched to the returned tickets. Reopen the app while signed in and retry verification.',
      );
    }
    final tickets = <Ticket>[];
    for (final value in values) {
      final ticket = Ticket.fromServer(value, authenticatedUserId: userId);
      if (ticket.id.isEmpty) {
        throw const ApiException('The server returned a ticket without an ID.');
      }
      if (ticket.userId != userId) {
        throw const ApiException(
          'The server returned a ticket belonging to another account.',
        );
      }
      if (ticket.isIssued && ticket.qrPayload.isNotEmpty) tickets.add(ticket);
    }
    if (tickets.isNotEmpty) await _ticketsController.addTickets(tickets);
    return tickets;
  }

  List<Map<String, dynamic>> _ticketValues(Map<String, dynamic> orderData) {
    final values = orderData['tickets'] ?? orderData['ticket'];
    if (values is List) {
      return values.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (values is Map) return [Map<String, dynamic>.from(values)];
    final nestedOrder = orderData['order'];
    if (nestedOrder is Map) {
      return _ticketValues(Map<String, dynamic>.from(nestedOrder));
    }
    return const [];
  }

  Map<String, dynamic> _nestedMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<OrderItem> _parseOrderItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _firstString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return fallback;
  }

  int _integer(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed.toInt();
      }
    }
    return 0;
  }

  void _clearIdempotencyState() {
    _pendingIdempotencyKey = null;
    _pendingOrderFingerprint = null;
    _pendingVerification = false;
    _paymentState = 'paid';
    SharedPreferences.getInstance().then(
      (preferences) => preferences.remove(pendingOrderPreference),
    );
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String status,
    String persistenceFailureMessage,
  ) async {
    try {
      await _orderRepository.updateOrderStatus(orderId, status);
    } catch (_) {
      failureReason = persistenceFailureMessage;
    }
  }
}

final paymentServiceGlobal = paymentService;
final ticketsControllerGlobal = ticketsController;
