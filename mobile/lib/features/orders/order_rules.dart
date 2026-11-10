import 'models/order.dart';

/// Maximum number of tickets permitted in one order (enforced by backend).
const int maxTicketsPerOrder = 10;

/// Order selection must use exactly one ticket type and stay within the limit.
bool hasValidTicketSelection(List<OrderItem> items) =>
    items.length == 1 &&
    items.single.quantity >= 1 &&
    items.single.quantity <= maxTicketsPerOrder;
