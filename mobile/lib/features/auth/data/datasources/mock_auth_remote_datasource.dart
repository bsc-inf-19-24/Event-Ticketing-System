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
  UserModel? _currentUser;

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final user = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );
      _currentUser = UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        token: 'mock_jwt_secure_token_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: 'mock_refresh_token',
      );
      return _currentUser!;
    } on AuthException catch (exception) {
      throw ApiException(exception.message, 400);
    }
  }

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final user = await _authService.logIn(email: email, password: password);
      _currentUser = UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        token: 'mock_jwt_secure_token_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: 'mock_refresh_token',
      );
      return _currentUser!;
    } on AuthException {
      throw ApiException('Invalid email or password. Please try again.', 401);
    }
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) {
    throw const ApiException('Google sign-in is unavailable in demo mode.');
  }

  @override
  Future<UserModel> getCurrentProfile() async {
    final user = _currentUser;
    if (user == null) {
      throw ApiException('No signed-in demo user is available.', 401);
    }
    return user;
  }

  @override
  Future<AuthTokens> refreshTokens(String refreshToken) async {
    if (refreshToken != 'mock_refresh_token') {
      throw const ApiException('The refresh token is invalid.', 401);
    }
    return AuthTokens(
      accessToken:
          'mock_jwt_secure_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: refreshToken,
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
