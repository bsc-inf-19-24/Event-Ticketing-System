//abstract repository contract
import 'package:mobile/features/auth/data/model/user_model.dart';

import '../entities/password_reset_request.dart';

abstract class AuthRepository {
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  });
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginWithGoogle(String idToken);
  Future<UserModel?> restoreSession();
  Future<void> logout();
  Future<PasswordResetRequest> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
