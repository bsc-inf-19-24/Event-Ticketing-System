/// Supported simulated payment methods.
enum PaymentMethod { airtelMoney, tnmMpamba, card }

/// PayChangu-shaped checkout request used only by the local simulator.
class PaymentRequest {
  const PaymentRequest({
    required this.amount,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.txRef,
    this.mobile,
    this.currency = 'MWK',
    this.callbackUrl = 'https://example.invalid/callback',
    this.returnUrl = 'https://example.invalid/return',
    this.customizationTitle = 'Ticket purchase',
    this.customizationDescription = 'Ticket Master test checkout',
    this.meta = const {},
  });

  final int amount;
  final String currency;
  final String email;
  final String firstName;
  final String lastName;
  final String txRef;
  final String? mobile;
  final String callbackUrl;
  final String returnUrl;
  final String customizationTitle;
  final String customizationDescription;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'tx_ref': txRef,
    if (mobile != null && mobile!.isNotEmpty) 'mobile': mobile,
    'callback_url': callbackUrl,
    'return_url': returnUrl,
    'customization': {
      'title': customizationTitle,
      'description': customizationDescription,
    },
    'meta': meta,
  };
}

/// Details returned when a hosted checkout session is created.
class CheckoutSession {
  const CheckoutSession({
    required this.txRef,
    required this.checkoutUrl,
    required this.currency,
    required this.amount,
    required this.mode,
    required this.status,
  });

  final String txRef;
  final String checkoutUrl;
  final String currency;
  final int amount;
  final String mode;
  final String status;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);
    final checkoutData = Map<String, dynamic>.from(data['data'] as Map);
    return CheckoutSession(
      txRef: checkoutData['tx_ref'] as String? ?? '',
      checkoutUrl: data['checkout_url'] as String? ?? '',
      currency: checkoutData['currency'] as String? ?? 'MWK',
      amount: (checkoutData['amount'] as num?)?.toInt() ?? 0,
      mode: checkoutData['mode'] as String? ?? 'test',
      status: checkoutData['status'] as String? ?? 'pending',
    );
  }
}

/// Verification details returned by the payment simulator.
class PaymentVerification {
  const PaymentVerification({
    required this.txRef,
    required this.status,
    required this.currency,
    required this.amount,
    required this.mode,
    required this.type,
    required this.attempts,
  });

  final String txRef;
  final String status;
  final String currency;
  final int amount;
  final String mode;
  final String type;
  final int attempts;

  factory PaymentVerification.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);
    return PaymentVerification(
      txRef: data['tx_ref'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      currency: data['currency'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      mode: data['mode'] as String? ?? '',
      type: data['type'] as String? ?? '',
      attempts: (data['number_of_attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An available mobile-money operator.
class MobileMoneyOperator {
  const MobileMoneyOperator({required this.refId, required this.name});

  final String refId;
  final String name;

  Map<String, dynamic> toJson() => {'ref_id': refId, 'name': name};

  factory MobileMoneyOperator.fromJson(Map<String, dynamic> json) =>
      MobileMoneyOperator(
        refId: json['ref_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// A simulated mobile-money charge.
/// Exact field names must be confirmed against the PayChangu reference.
class MobileMoneyCharge {
  const MobileMoneyCharge({
    required this.chargeId,
    required this.refId,
    required this.mobile,
    required this.amount,
    required this.currency,
    required this.status,
  });

  final String chargeId;
  final String refId;
  final String mobile;
  final int amount;
  final String currency;
  final String status;

  factory MobileMoneyCharge.fromJson(Map<String, dynamic> json) =>
      MobileMoneyCharge(
        chargeId: json['charge_id'] as String? ?? '',
        refId: json['ref_id'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'MWK',
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
    'charge_id': chargeId,
    'ref_id': refId,
    'mobile': mobile,
    'amount': amount,
    'currency': currency,
    'status': status,
  };
}

/// User-selected result for a simulated payment.
enum PaymentOutcome { success, failed, cancelled }
