class ApiEndpoints {
  static const register = '/api/auth/register';
  static const login = '/api/auth/login';
  static const refresh = '/api/auth/refresh';
  static const me = '/api/customers/me';

  static const events = '/api/events';
  static String event(String id) => '/api/events/$id';
  static String ticketTypes(String eventId) =>
      '/api/events/$eventId/ticket-types';

  static const orders = '/api/orders';
  static String orderTickets(String id) => '/api/orders/$id/tickets';
  static String cancelOrder(String id) => '/api/orders/$id/cancel';
  static const myOrders = '/api/orders/my';
  static String order(String id) => '/api/orders/$id';
  static String orderPayment(String orderId) =>
      '$orders/${Uri.encodeComponent(orderId)}/payment';

  static const paymentCheckout = '/api/payments/checkout'; // body {orderId}
  static const paymentVerify = '/api/payments/verify'; // body {orderId}
  static String demoMarkPaid(String orderId) =>
      '/api/dev/orders/${Uri.encodeComponent(orderId)}/mark-paid';
  static String demoConfirm(String orderId) => demoMarkPaid(orderId);

  static const myTickets = '/api/tickets/my';
}
