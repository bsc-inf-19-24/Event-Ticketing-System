// manages loading state and error
import 'package:flutter/foundation.dart';
import 'package:mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile/features/auth/domain/usecases/register_usecase.dart';
import 'package:mobile/features/auth/domain/usecases/password_reset_usecase.dart';
import 'package:mobile/features/auth/domain/entities/password_reset_request.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
Future<void>? _googleSignInInitialization;

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final PasswordResetUseCase passwordResetUseCase;
  final AuthRepository? authRepository;
  final AuthRepository authRepository;

  AuthProvider({
    required this.loginUseCase,
    required this.passwordResetUseCase,
    this.authRepository,
  });
    RegisterUseCase? registerUseCase,
    AuthRepository? authRepository,
  }) : registerUseCase =
           registerUseCase ??
           RegisterUseCase(repository: loginUseCase.repository),
       authRepository = authRepository ?? loginUseCase.repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _sessionRestoreError;
  String? get sessionRestoreError => _sessionRestoreError;

  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  bool get isLoggedIn => authController.isLoggedIn;

  Future<void> restoreSession() async {
    _isLoading = true;
    _sessionRestoreError = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await authRepository.restoreSession();
      if (user != null) _setAuthenticatedUser(user);
    } catch (error) {
      _sessionRestoreError = _messageFrom(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionRestoreError = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final user = await registerUseCase.execute(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _setAuthenticatedUser(user);
      _isSuccess = true;
      return true;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionRestoreError = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final user = await loginUseCase.execute(email, password);

      authController.setAuthenticatedUser(
        AppUser(
          id: user.id,
          name: user.name.isEmpty ? user.email.split('@').first : user.name,
          email: user.email,
        ),
      );
      _setAuthenticatedUser(user);

      _isLoading = false;
      _isSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Extracts clean error message from ApiExceptions or general exceptions
      _errorMessage = _messageFrom(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (authRepository == null) {
        throw Exception('Google sign-in is unavailable in this configuration.');
      }
      final google = GoogleSignIn.instance;
      _googleSignInInitialization ??= google.initialize(
        clientId: _googleClientId.isEmpty ? null : _googleClientId,
        serverClientId: _googleServerClientId.isEmpty
            ? null
            : _googleServerClientId,
      );
      await _googleSignInInitialization;
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token. Check your OAuth client configuration.');
      }
      final user = await authRepository!.loginWithGoogle(idToken);
      authController.setAuthenticatedUser(AppUser(
        id: user.id,
        name: user.name.isEmpty ? user.email.split('@').first : user.name,
        email: user.email,
      ));
      _isSuccess = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
  Future<bool> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionRestoreError = null;
    _isSuccess = false;
    notifyListeners();
    try {
      final user = await authRepository.loginWithGoogle(idToken);
      _setAuthenticatedUser(user);
      _isSuccess = true;
      return true;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    _sessionRestoreError = null;
    notifyListeners();
    try {
      await authRepository.logout();
      authController.logOut();
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setAuthenticatedUser(User user) {
    authController.setAuthenticatedUser(
      AppUser(
        id: user.id,
        name: user.name?.isNotEmpty == true
            ? user.name!
            : user.email.split('@').first,
        email: user.email,
      ),
    );
  }

  String _messageFrom(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await passwordResetUseCase.requestReset(email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await passwordResetUseCase.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
