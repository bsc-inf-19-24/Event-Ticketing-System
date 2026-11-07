import '../../../../core/network/api_client.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/auth/services/auth_service.dart';

import 'auth_remote_datasource.dart';
import '../../domain/entities/password_reset_request.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  MockAuthRemoteDataSource({FakeAuthService? authService})
    : _authService = authService ?? FakeAuthService();

  final FakeAuthService _authService;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final user = await _authService.logIn(email: email, password: password);
      return UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        token: 'mock_jwt_secure_token_${DateTime.now().millisecondsSinceEpoch}',
      );
    } on AuthException {
      throw ApiException('Invalid email or password. Please try again.', 401);
    }
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) async {
    throw ApiException(
      'Google sign-in requires a configured backend. Set API_BASE_URL and configure POST /auth/google.',
      501,
    );
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    try {
      final code = await _authService.requestPasswordReset(email: email);
      return PasswordResetRequest(
        message:
            'A reset code was created for your account. Demo mode does not '
            'send email; use the code shown below.',
        demoVerificationCode: code,
      );
    } on AuthException catch (exception) {
      throw ApiException(exception.message, 404);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
    } on AuthException catch (exception) {
      throw ApiException(exception.message, 400);
    }
  }
}
