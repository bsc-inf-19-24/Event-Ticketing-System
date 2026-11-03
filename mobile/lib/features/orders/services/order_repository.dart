import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/tickets/logic/tickets_controller.dart';
import '../../../models/event.dart';
import '../../../models/ticket.dart';
import '../../../services/ticket_storage.dart';
import '../models/order.dart';

/// Stores orders separately from ticket records in the existing preferences store.
class OrderRepository {
  static final Map<String, Future<void>> _orderLocks = {};
  static const _ordersKey = 'ticket_master_orders';
  final Random _random;
  final TicketStorage _ticketStorage;

  OrderRepository({Random? random, TicketStorage? ticketStorage})
    : _random = random ?? Random(),
      _ticketStorage = ticketStorage ?? TicketStorage();

  Future<List<Order>> _readOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ordersKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Order.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _writeOrders(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ordersKey,
      jsonEncode(orders.map((order) => order.toJson()).toList()),
    );
  }

  /// Adds or replaces a locally stored order.
  Future<void> saveOrder(Order order) async {
    final orders = await _readOrders();
    final index = orders.indexWhere((saved) => saved.id == order.id);
    if (index < 0) {
      orders.add(order);
    } else {
      orders[index] = order;
    }
    await _writeOrders(orders);
  }

  /// Updates the status of an existing order.
  Future<void> updateOrderStatus(String orderId, String status) async {
    final orders = await _readOrders();
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index < 0) throw StateError('Order could not be found.');
    orders[index] = orders[index].copyWith(status: status);
    await _writeOrders(orders);
  }

  /// Returns only orders belonging to the requested customer.
  Future<List<Order>> getOrdersForUser(String userId) async =>
      (await _readOrders()).where((order) => order.userId == userId).toList();

  /// Creates each purchased ticket once, only when its order can be marked paid.
  Future<List<Ticket>> completePaidOrder({
    required Order order,
    required Event event,
    required TicketsController ticketsController,
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
    );
  }

  Future<List<Ticket>> _completePaidOrderSerially({
    required Future<void> previous,
    required Completer<void> completion,
    required Order order,
    required Event event,
    required TicketsController ticketsController,
  }) async {
    await previous;
    try {
      return await _createTicketsForPaidOrder(
        order: order,
        event: event,
        ticketsController: ticketsController,
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
  }) async {
    final orders = await _readOrders();
    final index = orders.indexWhere((saved) => saved.id == order.id);
    if (index < 0) throw StateError('Order could not be found.');
    if (orders[index].status == 'paid') return [];

    final tickets = <Ticket>[];
    final ids = (await _ticketStorage.getSavedTickets())
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
          ),
        );
      }
    }
    await ticketsController.addTickets(tickets);
    orders[index] = orders[index].copyWith(status: 'paid');
    await _writeOrders(orders);
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
