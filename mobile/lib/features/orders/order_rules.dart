import 'models/order.dart';

/// Maximum number of tickets permitted in one order.
const int maxTicketsPerOrder = 1;

/// Whether an order has exactly one selected ticket type within the limit.
bool hasValidTicketSelection(List<OrderItem> items) =>
    items.length == 1 &&
    items.single.quantity >= 1 &&
    items.single.quantity <= maxTicketsPerOrder;
