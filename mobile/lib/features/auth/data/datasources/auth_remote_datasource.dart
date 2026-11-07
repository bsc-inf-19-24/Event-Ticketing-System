//calls POST /auth/login
import '../../../../core/network/api_client.dart';
import '../../domain/entities/password_reset_request.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginWithGoogle(String idToken);
  Future<PasswordResetRequest> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserModel> login(String email, String password) async {
    // Calls POST /auth/login with the credentials
    final responseData = await apiClient.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    return UserModel.fromJson(responseData);
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) async {
    if (idToken.trim().isEmpty) {
      throw ApiException('Google did not return an ID token.');
    }
    final responseData = await apiClient.post('/auth/google', {
      'idToken': idToken,
    });
    return UserModel.fromJson(responseData);
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    final responseData = await apiClient.post('/auth/forgot-password', {
      'email': email.trim(),
    });

    return PasswordResetRequest(
      message: responseData['message'] is String
          ? responseData['message'] as String
          : 'If an account exists, a verification code has been sent.',
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await apiClient.post('/auth/reset-password', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }
}
