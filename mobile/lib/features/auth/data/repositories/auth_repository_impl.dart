//implements repository interface
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/password_reset_request.dart';
import '../datasources/auth_remote_datasource.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/core/network/api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorageService secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  Future<void> _saveTokens(UserModel user) async {
    if (user.token.isEmpty || user.refreshToken.isEmpty) {
      throw const ApiException(
        'The server did not return both authentication tokens.',
      );
    }
    await secureStorage.saveTokens(
      accessToken: user.token,
      refreshToken: user.refreshToken,
    );
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final user = await remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    await _saveTokens(user);
    return user;
  }

  @override
  Future<UserModel> login(String email, String password) async {
    final userModel = await remoteDataSource.login(email, password);
    await _saveTokens(userModel);
    return userModel;
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) async {
    final userModel = await remoteDataSource.loginWithGoogle(idToken);
    await _saveTokens(userModel);
    return userModel;
  }

  @override
  Future<UserModel> loginWithGoogle(String idToken) async {
    final userModel = await remoteDataSource.loginWithGoogle(idToken);
    if (userModel.token.isEmpty) {
      throw Exception('The server did not return an authentication token.');
    }
    await secureStorage.saveToken(userModel.token);
    return userModel;
  }

  @override
  Future<UserModel?> restoreSession() async {
    final token = await secureStorage.getToken();
    if (token == null || token.isEmpty) return null;

    final profile = await remoteDataSource.getCurrentProfile();
    return UserModel(
      id: profile.id,
      email: profile.email,
      name: profile.name,
      token: token,
      refreshToken: await secureStorage.getRefreshToken() ?? '',
    );
  }

  @override
  Future<void> logout() => secureStorage.clearTokens();

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) {
    return remoteDataSource.requestPasswordReset(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return remoteDataSource.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
}
