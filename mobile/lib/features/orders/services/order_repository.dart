import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/tickets/logic/tickets_controller.dart';
import '../../../models/event.dart';
import '../../../models/ticket.dart';
import '../../../services/ticket_storage.dart';
import '../../../core/storage/storage_scope.dart';
import '../models/order.dart';
import '../order_rules.dart';

/// Stores orders separately from ticket records in the existing preferences store.
class OrderRepository {
  static final Map<String, Future<void>> _orderLocks = {};
  static const _ordersPrefix = 'ticket_master_orders';
  static const _legacyOrdersKey = 'ticket_master_orders';
  static const _orderMigrationKey = 'ticket_orders_scope_v1';
  final Random _random;
  final TicketStorage _ticketStorage;

  OrderRepository({Random? random, TicketStorage? ticketStorage})
    : _random = random ?? Random(),
      _ticketStorage = ticketStorage ?? TicketStorage();

  static Future<void> migrateLegacyOrders() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_orderMigrationKey) ?? false) return;
    await prefs.remove(_legacyOrdersKey);
    await prefs.remove('pending_payment_order_id');
    await prefs.setBool(_orderMigrationKey, true);
  }

  Future<List<Order>> _readOrders({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageScope.key(_ordersPrefix, userId: userId);
    if (key == null) return [];
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Order.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _writeOrders(List<Order> orders, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageScope.key(_ordersPrefix, userId: userId);
    if (key == null) return;
    await prefs.setString(
      key,
      jsonEncode(orders.map((order) => order.toJson()).toList()),
    );
  }

  /// Adds or replaces a locally stored order.
  Future<void> saveOrder(Order order) async {
    if (order.userId.isEmpty) throw StateError('Order owner is required.');
    final orders = await _readOrders(userId: order.userId);
    final index = orders.indexWhere((saved) => saved.id == order.id);
    if (index < 0) {
      orders.add(order);
    } else {
      orders[index] = order;
    }
    await _writeOrders(orders, userId: order.userId);
  }

  /// Updates the status of an existing order.
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? userId,
  }) async {
    final scope = userId ?? StorageScope.currentKey();
    if (scope == null) throw StateError('A logged-in customer is required.');
    final orders = await _readOrders(userId: scope);
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index < 0) throw StateError('Order could not be found.');
    orders[index] = orders[index].copyWith(status: status);
    await _writeOrders(orders, userId: scope);
  }

  /// Returns only orders belonging to the requested customer.
  Future<List<Order>> getOrdersForUser(String userId) async =>
      (await _readOrders(userId: userId))
          .where((order) => order.userId == userId)
          .toList();

  /// Creates each purchased ticket once, only when its order can be marked paid.
  Future<List<Ticket>> completePaidOrder({
    required Order order,
    required Event event,
    required TicketsController ticketsController,
    required String buyerName,
    required String buyerEmail,
  }) {
    final previous = _orderLocks[order.id] ?? Future<void>.value();
    final completion = Completer<void>();
    _orderLocks[order.id] = completion.future;
    return _completePaidOrderSerially(
      previous: previous,
      completion: completion,
      order: order,
      event: event,
      ticketsController: ticketsController,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
    );
  }

  Future<List<Ticket>> _completePaidOrderSerially({
    required Future<void> previous,
    required Completer<void> completion,
    required Order order,
    required Event event,
    required TicketsController ticketsController,
    required String buyerName,
    required String buyerEmail,
  }) async {
    await previous;
    try {
      return await _createTicketsForPaidOrder(
        order: order,
        event: event,
        ticketsController: ticketsController,
        buyerName: buyerName,
        buyerEmail: buyerEmail,
      );
    } finally {
      completion.complete();
      if (identical(_orderLocks[order.id], completion.future)) {
        _orderLocks.remove(order.id);
      }
    }
  }

  Future<List<Ticket>> _createTicketsForPaidOrder({
    required Order order,
    required Event event,
    required TicketsController ticketsController,
    required String buyerName,
    required String buyerEmail,
  }) async {
    if (!hasValidTicketSelection(order.items)) {
      throw StateError(
        'Order must contain exactly one ticket type and ticket.',
      );
    }
    final orders = await _readOrders(userId: order.userId);
    final index = orders.indexWhere((saved) => saved.id == order.id);
    if (index < 0) throw StateError('Order could not be found.');
    if (orders[index].status == 'paid') return [];

    final tickets = <Ticket>[];
    final ids = (await _ticketStorage.getSavedTickets(userId: order.userId))
        .map((ticket) => ticket.id)
        .toSet();
    for (final item in order.items) {
      for (var i = 0; i < item.quantity; i++) {
        String id;
        do {
          id = 'TM-${_random.nextInt(1000000).toString().padLeft(6, '0')}';
        } while (!ids.add(id));
        tickets.add(
          Ticket(
            id: id,
            eventName: event.title,
            date: event.date,
            venue: event.venue,
            status: 'Confirmed',
            qrData: 'TM|${order.id}|$id|${order.txRef}',
            ticketType: item.ticketTypeName,
            price: item.unitPrice,
            purchasedOn: _formatPurchaseDate(DateTime.now()),
            imagePath: event.imagePath,
            userId: order.userId,
            paymentId: order.txRef,
            orderId: order.id,
            buyerName: buyerName,
            buyerEmail: buyerEmail,
          ),
        );
      }
    }
    await ticketsController.addTickets(tickets);
    orders[index] = orders[index].copyWith(status: 'paid');
    await _writeOrders(orders, userId: order.userId);
    return tickets;
  }

  String _formatPurchaseDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
