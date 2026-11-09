/// API paths shared by authenticated order, payment, and ticket requests.
class ApiEndpoints {
  static const orders = '/api/orders';
  static const myOrders = '$orders/my';

  // Confirm these payment routes with the backend before production use.
  static String orderPayment(String orderId) =>
      '$orders/${Uri.encodeComponent(orderId)}/payment';
  static String demoConfirm(String orderId) =>
      '$orders/${Uri.encodeComponent(orderId)}/demo-confirm';
}
