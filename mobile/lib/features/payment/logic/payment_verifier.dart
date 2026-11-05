import '../models/payment_models.dart';

/// Accepts only a successful matching MWK transaction for at least the due amount.
bool isPaymentVerified(
  PaymentVerification verification, {
  required String expectedTxRef,
  required int expectedAmount,
}) =>
    verification.txRef == expectedTxRef &&
    verification.status == 'success' &&
    verification.currency == 'MWK' &&
    verification.amount >= expectedAmount;
