//abstract repository contract
import 'package:mobile/features/auth/data/model/user_model.dart';

import '../entities/password_reset_request.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginWithGoogle(String idToken);
  Future<PasswordResetRequest> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
