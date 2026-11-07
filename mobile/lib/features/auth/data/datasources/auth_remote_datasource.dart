import '../../../../core/network/api_client.dart';
import '../../domain/entities/password_reset_request.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  });
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginWithGoogle(String idToken);
  Future<UserModel> getCurrentProfile();
  Future<AuthTokens> refreshTokens(String refreshToken);
  Future<PasswordResetRequest> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}

class ApiAuthService implements AuthRemoteDataSource {
  final ApiClient apiClient;

  ApiAuthService({required this.apiClient});

  Map<String, dynamic> _responseMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const ApiException('The server returned an invalid response.');
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await apiClient.postUnauthenticated('/api/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': role,
    });
    return UserModel.fromJson(_responseMap(response));
  }

  @override
  Future<UserModel> login(String email, String password) async {
    final responseData = await apiClient.postUnauthenticated(
      '/api/auth/login',
      {'email': email.trim(), 'password': password},
    );

    return UserModel.fromJson(_responseMap(responseData));
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
    final response = await apiClient.postUnauthenticated('/api/auth/google', {
      'idToken': idToken,
    });
    return UserModel.fromJson(_responseMap(response));
  }

  Future<List<int>> generateQrImage(String text) {
    return apiClient.getBytes(
      '/api/auth/qr/${Uri.encodeComponent(text)}',
      authenticated: false,
    );
  }

  @override
  Future<UserModel> getCurrentProfile() async {
    final response = await apiClient.get('/api/customers/me');
    return UserModel.fromJson(_responseMap(response));
  }

  @override
  Future<AuthTokens> refreshTokens(String refreshToken) async {
    final response = await apiClient.postWithoutRefresh('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    try {
      return AuthTokens.fromJson(_responseMap(response));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    final responseData = await apiClient.postUnauthenticated(
      '/api/auth/forgot-password',
      {'email': email.trim()},
    );
    final body = _responseMap(responseData);

    return PasswordResetRequest(
      message: body['message'] is String
          ? body['message'] as String
          : 'If an account exists, a verification code has been sent.',
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await apiClient.postUnauthenticated('/api/auth/reset-password', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }
}

class AuthRemoteDataSourceImpl extends ApiAuthService {
  AuthRemoteDataSourceImpl({required super.apiClient});
}
