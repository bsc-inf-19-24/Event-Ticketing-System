import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../features/auth/logic/auth_controller.dart';
import '../../../features/orders/models/order.dart';
import '../../../features/orders/order_rules.dart';
import '../../../features/orders/services/order_repository.dart';
import '../../../features/tickets/logic/tickets_controller.dart';
import '../../../models/event.dart';
import '../../../models/ticket.dart';
import '../models/payment_models.dart';
import '../services/fake_payment_service.dart';
import '../services/payment_service.dart';
import 'payment_verifier.dart';

/// Coordinates a simulated payment, order persistence, and ticket creation.
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
  bool isProcessing = false;
  String? failureReason;
  List<Ticket> purchasedTickets = const [];
  String _buyerName = '';
  String _buyerEmail = '';

  /// Persists an order and starts the chosen local payment simulation.
  Future<void> begin({
    required Event event,
    required List<OrderItem> items,
    required int total,
    required PaymentMethod method,
    required String phone,
  }) async {
    if (!hasValidTicketSelection(items)) {
      throw const PaymentException(
        'Choose exactly one ticket type and one ticket to continue.',
      );
    }
    final user = _auth.user;
    if (user == null) {
      throw const PaymentException('Please log in to continue.');
    }
    isProcessing = true;
    failureReason = null;
    _buyerName = user.name;
    _buyerEmail = user.email;
    notifyListeners();
    final now = DateTime.now();
    final randomDigits = _random.nextInt(10000).toString().padLeft(4, '0');
    final txRef = 'TM-${now.millisecondsSinceEpoch}-$randomDigits';
    final createdOrder = Order(
      id: 'ORD-${now.millisecondsSinceEpoch}-$randomDigits',
      userId: user.id,
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
    try {
      await _orderRepository.saveOrder(createdOrder);
      order = createdOrder;
      if (method == PaymentMethod.card) {
        final names = user.name.trim().split(RegExp(r'\s+'));
        await _paymentService.initiateCheckout(
          PaymentRequest(
            amount: total,
            email: user.email,
            firstName: names.first,
            lastName: names.length > 1 ? names.skip(1).join(' ') : '',
            txRef: txRef,
            meta: {'order_id': createdOrder.id},
          ),
        );
      } else {
        await _paymentService.chargeMobileMoney(
          operatorRefId: method == PaymentMethod.airtelMoney
              ? 'airtel-money'
              : 'tnm-mpamba',
          mobile: phone,
          amount: total,
          chargeId: txRef,
        );
      }
    } catch (error) {
      await _orderRepository.updateOrderStatus(createdOrder.id, 'failed');
      rethrow;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  /// Completes and verifies the transaction, creating tickets only on success.
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
    isProcessing = true;
    failureReason = null;
    notifyListeners();
    try {
      _paymentService.completePayment(currentOrder.txRef, outcome);
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
        verification = await _paymentService.verifyPayment(currentOrder.txRef);
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
    } catch (_) {
      failureReason = 'We could not verify your payment. Please try again.';
      await _updateOrderStatus(
        currentOrder.id,
        'failed',
        'We could not verify or save your payment. Please contact support.',
      );
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
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

// These aliases avoid shadowing the injectable constructor parameters.
final paymentServiceGlobal = paymentService;
final ticketsControllerGlobal = ticketsController;
