import 'dart:math';

import '../models/payment_models.dart';
import 'payment_service.dart';
import 'paychangu_payment_service.dart';

class _Transaction {
  _Transaction({
    required this.txRef,
    required this.amount,
    required this.currency,
    required this.mobile,
    required this.operatorRefId,
  });

  final String txRef;
  final int amount;
  final String currency;
  final String? mobile;
  final String? operatorRefId;
  String status = 'pending';
  int attempts = 0;
}

/// Fully offline implementation that returns PayChangu-shaped test responses.
class FakePaymentService implements PaymentService {
  final Map<String, _Transaction> _transactions = {};
  final Random _random;

  FakePaymentService({Random? random}) : _random = random ?? Random();

  Future<void> _delay() =>
      Future<void>.delayed(Duration(milliseconds: 600 + _random.nextInt(301)));

  @override
  Future<List<MobileMoneyOperator>> getMobileMoneyOperators() async {
    await _delay();
    return [
      MobileMoneyOperator.fromJson({
        'ref_id': 'airtel-money',
        'name': 'Airtel Money',
      }),
      MobileMoneyOperator.fromJson({
        'ref_id': 'tnm-mpamba',
        'name': 'TNM Mpamba',
      }),
    ];
  }

  @override
  Future<CheckoutSession> initiateCheckout(PaymentRequest request) async {
    await _delay();
    if (_transactions.containsKey(request.txRef)) {
      throw const PaymentException('This payment reference already exists.');
    }
    _transactions[request.txRef] = _Transaction(
      txRef: request.txRef,
      amount: request.amount,
      currency: request.currency,
      mobile: null,
      operatorRefId: null,
    );
    return CheckoutSession.fromJson({
      'message': 'Hosted payment session generated successfully.',
      'status': 'success',
      'data': {
        'event': 'checkout.session:created',
        'checkout_url': 'https://checkout.paychangu.com/${request.txRef}',
        'data': {
          'tx_ref': request.txRef,
          'currency': request.currency,
          'amount': request.amount,
          'mode': 'test',
          'status': 'pending',
        },
      },
    });
  }

  @override
  Future<MobileMoneyCharge> chargeMobileMoney({
    required String operatorRefId,
    required String mobile,
    required int amount,
    required String chargeId,
  }) async {
    await _delay();
    if (_transactions.containsKey(chargeId)) {
      throw const PaymentException('This payment reference already exists.');
    }
    _transactions[chargeId] = _Transaction(
      txRef: chargeId,
      amount: amount,
      currency: 'MWK',
      mobile: mobile,
      operatorRefId: operatorRefId,
    );
    return MobileMoneyCharge.fromJson({
      'charge_id': chargeId,
      'ref_id': operatorRefId,
      'mobile': mobile,
      'amount': amount,
      'currency': 'MWK',
      'status': 'pending',
    });
  }

  @override
  Future<PaymentVerification> verifyPayment(String txRef) async {
    await _delay();
    final transaction = _transactions[txRef];
    if (transaction == null) {
      throw const PaymentException('Payment could not be found.');
    }
    transaction.attempts++;
    return PaymentVerification.fromJson({
      'status': 'success',
      'message': 'Payment details retrieved successfully.',
      'data': {
        'event_type': 'checkout.payment',
        'tx_ref': transaction.txRef,
        'mode': 'test',
        'type': 'API Payment (Checkout)',
        'status': transaction.status,
        'currency': transaction.currency,
        'amount': transaction.amount,
        'number_of_attempts': transaction.attempts,
        'created_at': '',
        'updated_at': '',
      },
    });
  }

  @override
  void completePayment(String txRef, PaymentOutcome outcome) {
    final transaction = _transactions[txRef];
    if (transaction == null) {
      throw const PaymentException('Payment could not be found.');
    }
    transaction.status = switch (outcome) {
      PaymentOutcome.success => 'success',
      PaymentOutcome.failed || PaymentOutcome.cancelled => 'failed',
    };
  }
}

const useFakePayments = bool.fromEnvironment(
  'USE_FAKE_PAYMENTS',
  defaultValue: true,
);

/// Set USE_FAKE_PAYMENTS=false for the backend-backed PayChangu flow.
final PaymentService paymentService = useFakePayments
    ? FakePaymentService()
    : PayChanguPaymentService();
