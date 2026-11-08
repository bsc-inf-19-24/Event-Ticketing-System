import '../../../../core/network/api_client.dart';
import '../../domain/entities/password_reset_request.dart';
import '../model/user_model.dart';

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
  ApiAuthService({required this.apiClient});

  final ApiClient apiClient;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
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
  }) async => UserModel.fromJson(
    _map(
      await apiClient.postUnauthenticated('/api/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      }),
    ),
  );

  @override
  Future<UserModel> login(String email, String password) async =>
      UserModel.fromJson(
        _map(
          await apiClient.postUnauthenticated('/api/auth/login', {
            'email': email.trim(),
            'password': password,
          }),
        ),
      );
  Future<UserModel> login(String email, String password) async {
    final response = await apiClient.postUnauthenticated('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return UserModel.fromJson(_responseMap(response));
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) async {
    if (idToken.trim().isEmpty) {
      throw const ApiException('Google did not return an ID token.');
    }
    return UserModel.fromJson(
      _map(
        await apiClient.postUnauthenticated('/api/auth/google', {
          'idToken': idToken,
        }),
      ),
    );
  }
    final response = await apiClient.postUnauthenticated('/api/auth/google', {
      'idToken': idToken,
    });
    return UserModel.fromJson(_responseMap(response));
  }

  Future<List<int>> generateQrImage(String text) => apiClient.getBytes(
    '/api/auth/qr/${Uri.encodeComponent(text)}',
    authenticated: false,
  );

  Future<List<int>> generateQrImage(String text) => apiClient.getBytes(
    '/api/auth/qr/${Uri.encodeComponent(text)}',
    authenticated: false,
  );

  @override
  Future<UserModel> getCurrentProfile() async =>
      UserModel.fromJson(_map(await apiClient.get('/api/customers/me')));

  @override
  Future<AuthTokens> refreshTokens(String refreshToken) async =>
      AuthTokens.fromJson(
        _map(
          await apiClient.postWithoutRefresh('/api/auth/refresh', {
            'refreshToken': refreshToken,
          }),
        ),
      );

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    final response = _map(
      await apiClient.postUnauthenticated('/api/auth/forgot-password', {
        'email': email.trim(),
      }),
    );
    final response = await apiClient.postUnauthenticated(
      '/api/auth/forgot-password',
      {'email': email.trim()},
    );
    final body = _responseMap(response);
    return PasswordResetRequest(
      message: response['message'] is String
          ? response['message'] as String
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
