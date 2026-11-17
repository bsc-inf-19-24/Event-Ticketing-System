//implements repository interface
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/password_reset_request.dart';
import '../datasources/auth_remote_datasource.dart';

import 'package:mobile/features/auth/data/model/user_model.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/models/app_user.dart';

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
    await secureStorage.saveUser(
      AppUser(
        id: user.id,
        name: user.name?.trim().isNotEmpty == true
            ? user.name!.trim()
            : user.email.split('@').first,
        email: user.email,
        role: user.role,
      ),
    );
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final returnedUser = await remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    final user = returnedUser.role.isEmpty
        ? UserModel(
            id: returnedUser.id,
            email: returnedUser.email,
            name: returnedUser.name,
            token: returnedUser.token,
            refreshToken: returnedUser.refreshToken,
            role: role,
          )
        : returnedUser;
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
  Future<UserModel?> restoreSession() async {
    final token = await secureStorage.getToken();
    if (token == null || token.isEmpty) return null;
    final cachedUser = await secureStorage.getUser();
    if (cachedUser != null) {
      return UserModel(
        id: cachedUser.id,
        email: cachedUser.email,
        name: cachedUser.name,
        role: cachedUser.role,
        token: token,
        refreshToken: await secureStorage.getRefreshToken() ?? '',
      );
    }
    final tokenUser = UserModel.fromJson({'token': token});
    if (tokenUser.email.isNotEmpty) {
      final user = AppUser(
        id: tokenUser.id,
        email: tokenUser.email,
        name: tokenUser.email.split('@').first,
        role: tokenUser.role,
      );
      await secureStorage.saveUser(user);
      return UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        token: token,
        refreshToken: await secureStorage.getRefreshToken() ?? '',
      );
    }
    final profile = await remoteDataSource.getCurrentProfile();
    await secureStorage.saveUser(
      AppUser(
        id: profile.id,
        email: profile.email,
        name: profile.name ?? '',
        role: profile.role,
      ),
    );
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
