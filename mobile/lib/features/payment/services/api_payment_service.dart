import '../../../core/api_client.dart';
import '../../../core/api_endpoints.dart';
import '../models/payment_models.dart';
import 'payment_service.dart';

/// Authenticated order and payment requests routed through the shared client.
class ApiPaymentService implements PaymentService {
  ApiPaymentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createOrder({
    required String eventId,
    required String ticketTypeId,
    required int quantity,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.orders,
      {'eventId': eventId, 'ticketTypeId': ticketTypeId, 'quantity': quantity},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _objectResponse(response, 'order');
  }

  Future<CheckoutSession> initiateOrderPayment({
    required String orderId,
    required PaymentMethod method,
    required String phone,
  }) async {
    final response = await _apiClient.post(ApiEndpoints.orderPayment(orderId), {
      'method': method.name,
      if (phone.isNotEmpty) 'phoneNumber': phone,
    });
    final data = _objectResponse(response, 'payment');
    final checkoutUrl = _firstString([
      data['checkoutUrl'],
      data['checkout_url'],
      data['paymentUrl'],
      data['payment_url'],
      _nested(data['payment'])['checkoutUrl'],
      _nested(data['payment'])['checkout_url'],
    ]);
    final txRef = _firstString([
      data['txRef'],
      data['tx_ref'],
      data['transactionReference'],
      data['transaction_reference'],
      _nested(data['payment'])['txRef'],
      _nested(data['payment'])['tx_ref'],
    ]);
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const PaymentException(
        'The server did not return a secure checkout URL.',
      );
    }
    return CheckoutSession(
      txRef: txRef.isEmpty ? orderId : txRef,
      checkoutUrl: uri.toString(),
      currency: _firstString([data['currency']], fallback: 'MWK'),
      amount: _intValue([data['amount'], data['total'], data['totalAmount']]),
      mode: _firstString([data['mode']], fallback: 'live'),
      status: _firstString([data['status']], fallback: 'pending'),
    );
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.orders}/${Uri.encodeComponent(orderId)}',
    );
    return _objectResponse(response, 'order');
  }

  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final response = await _apiClient.get(ApiEndpoints.myOrders);
    final data = response is Map ? response['data'] : null;
    final values = response is List
        ? response
        : data is List
        ? data
        : data is Map && data['orders'] is List
        ? data['orders'] as List
        : response is Map && response['orders'] is List
        ? response['orders'] as List
        : null;
    if (values == null || values.any((value) => value is! Map)) {
      throw const ApiException('The server returned an invalid order list.');
    }
    return values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  Future<Map<String, dynamic>> confirmDemoPayment(String orderId) async {
    final response = await _apiClient.post(
      ApiEndpoints.demoConfirm(orderId),
      const {},
    );
    return _objectResponse(response, 'payment confirmation');
  }

  @override
  Future<List<MobileMoneyOperator>> getMobileMoneyOperators() async => const [];

  @override
  Future<CheckoutSession> initiateCheckout(PaymentRequest request) =>
      throw const PaymentException(
        'Create an order before starting the payment.',
      );

  @override
  Future<MobileMoneyCharge> chargeMobileMoney({
    required String operatorRefId,
    required String mobile,
    required int amount,
    required String chargeId,
  }) => throw const PaymentException(
    'Mobile money payments use the hosted checkout flow.',
  );

  @override
  Future<PaymentVerification> verifyPayment(String txRef) =>
      throw const PaymentException(
        'Payment verification requires the order ID.',
      );

  @override
  void completePayment(String txRef, PaymentOutcome outcome) {}
}

Map<String, dynamic> _objectResponse(dynamic response, String name) {
  if (response is! Map) {
    throw ApiException('The server returned invalid $name data.');
  }
  var value = Map<String, dynamic>.from(response);
  for (var depth = 0; depth < 3; depth++) {
    final nested = value['data'] ?? value[name];
    if (nested is! Map) break;
    value = Map<String, dynamic>.from(nested);
  }
  return value;
}

Map<String, dynamic> _nested(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _firstString(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return fallback;
}

int _intValue(List<dynamic> values) {
  for (final value in values) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed.toInt();
    }
  }
  return 0;
}
