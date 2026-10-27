import '../../../../core/network/api_client.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/auth/services/auth_service.dart';

import 'auth_remote_datasource.dart';

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
        token: 'mock_jwt_secure_token_${DateTime.now().millisecondsSinceEpoch}',
      );
    } on AuthException {
      throw ApiException('Invalid email or password. Please try again.', 401);
    }
  }
}
