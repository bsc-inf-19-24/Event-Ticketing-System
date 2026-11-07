import '../models/payment_models.dart';

/// Defines the API surface used by a backend-backed or simulated payment service.
abstract class PaymentService {
  Future<List<MobileMoneyOperator>> getMobileMoneyOperators();
  Future<CheckoutSession> initiateCheckout(PaymentRequest request);
  Future<MobileMoneyCharge> chargeMobileMoney({
    required String operatorRefId,
    required String mobile,
    required int amount,
    required String chargeId,
  });
  Future<PaymentVerification> verifyPayment(String txRef);

  /// Simulators use this hook; real payments must be verified by the backend.
  void completePayment(String txRef, PaymentOutcome outcome);
}

/// Error returned for invalid or unknown simulated transactions.
class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}
