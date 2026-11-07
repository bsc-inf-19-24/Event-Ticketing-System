import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/payment_models.dart';
import 'payment_service.dart';

/// Calls the app backend. The PayChangu secret key must never be in this app.
class PayChanguPaymentService implements PaymentService {
  PayChanguPaymentService({
    http.Client? client,
    SecureStorageService? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? SecureStorageService();

  final http.Client _client;
  final SecureStorageService _secureStorage;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final token = await _secureStorage.getToken();
    final headers = ApiConfig.headers(token: token)
      ..['Accept'] = 'application/json';
    final response = switch (method) {
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      'GET' => await _client.get(uri, headers: headers),
      _ => throw StateError('Unsupported HTTP method: $method'),
    };

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const PaymentException('The payment server returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw PaymentException(
        message is String ? message : 'Could not process this payment.',
      );
    }
    return decoded;
  }

  @override
  Future<List<MobileMoneyOperator>> getMobileMoneyOperators() async =>
      const <MobileMoneyOperator>[];

  @override
  Future<CheckoutSession> initiateCheckout(PaymentRequest request) async {
    final payload = request.toJson()
      ..remove('callback_url')
      ..remove('return_url');
    final response = await _request(
      'POST',
      '/payments/paychangu/checkout',
      body: payload,
    );
    final session = CheckoutSession.fromJson(response);
    if (session.txRef != request.txRef ||
        !session.checkoutUrl.startsWith('https://')) {
      throw const PaymentException(
        'The payment server returned an invalid PayChangu checkout session.',
      );
    }
    return session;
  }

  @override
  Future<MobileMoneyCharge> chargeMobileMoney({
    required String operatorRefId,
    required String mobile,
    required int amount,
    required String chargeId,
  }) => throw const PaymentException(
    'Mobile money is handled through PayChangu hosted checkout.',
  );

  @override
  Future<PaymentVerification> verifyPayment(String txRef) async {
    final response = await _request(
      'GET',
      '/payments/paychangu/verify/${Uri.encodeComponent(txRef)}',
    );
    return PaymentVerification.fromJson(response);
  }

  /// Outcome selections are ignored; only the server's verified status counts.
  @override
  void completePayment(String txRef, PaymentOutcome outcome) {}
}
