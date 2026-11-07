import '../../../../core/network/api_client.dart';
import '../../domain/entities/password_reset_request.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/fake_auth_service.dart';
import '../model/user_model.dart';
import 'auth_remote_datasource.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  MockAuthRemoteDataSource({FakeAuthService? authService})
    : _authService = authService ?? FakeAuthService();

  final FakeAuthService _authService;
  UserModel? _currentUser;

  UserModel _asModel(AppUser user) => UserModel(
    id: user.id,
    name: user.name,
    email: user.email,
    token: 'mock_access_${DateTime.now().microsecondsSinceEpoch}',
    refreshToken: 'mock_refresh_token',
  );

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
      return _currentUser = _asModel(user);
    } on AuthException catch (error) {
      throw ApiException(error.message, 400);
    }
  }

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      return _currentUser = _asModel(
        await _authService.logIn(email: email, password: password),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message, 401);
    }
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) => Future<UserModel>.error(
    const ApiException('Google sign-in is unavailable in demo mode.', 501),
  );

  @override
  Future<UserModel> getCurrentProfile() async {
    final current = _currentUser;
    if (current == null) {
      throw const ApiException('No signed-in demo user is available.', 401);
    }
    return current;
  }

  @override
  Future<AuthTokens> refreshTokens(String refreshToken) async {
    if (refreshToken != 'mock_refresh_token') {
      throw const ApiException('The refresh token is invalid.', 401);
    }
    return AuthTokens(
      accessToken: 'mock_access_${DateTime.now().microsecondsSinceEpoch}',
      refreshToken: refreshToken,
    );
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    try {
      final code = await _authService.requestPasswordReset(email: email);
      return PasswordResetRequest(
        message: 'Demo reset code created. Use the code shown below.',
        demoVerificationCode: code,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message, 404);
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
    } on AuthException catch (error) {
      throw ApiException(error.message, 400);
    }
  }
}
