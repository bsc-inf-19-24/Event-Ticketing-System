class PasswordResetRequest {
  const PasswordResetRequest({
    required this.message,
    this.demoVerificationCode,
  });

  final String message;

  /// Only populated by the local mock service; production sends this by email.
  final String? demoVerificationCode;
}
