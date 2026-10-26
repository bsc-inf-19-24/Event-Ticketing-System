import '../../../../core/network/api_client.dart';
import 'package:mobile/features/auth/data/model/user_model.dart';
import 'auth_remote_datasource.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel> login(String email, String password) async {
    // Simulate network delay (e.g., 1 second server response time)
    await Future.delayed(const Duration(seconds: 1));

    // Define our dummy test account
    const dummyEmail = 'test.customer@example.com';
    const dummyPassword = 'SecurePassword123!';

    // Verify credentials
    if (email.trim().toLowerCase() == dummyEmail && password == dummyPassword) {
      return UserModel(
        id: 'user_mock_001',
        email: dummyEmail,
        token: 'mock_jwt_secure_token_xyz789',
      );
    } else {
      // Simulate backend throwing a 401 Unauthorized for incorrect credentials or unregistered accounts
      throw ApiException('Invalid email or password. Please try again.', 401);
    }
  }
}