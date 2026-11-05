import '../entities/password_reset_request.dart';
import '../repositories/auth_repository.dart';

class PasswordResetUseCase {
  const PasswordResetUseCase({required this.repository});

  final AuthRepository repository;

  Future<PasswordResetRequest> requestReset(String email) {
    return repository.requestPasswordReset(email);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
}
