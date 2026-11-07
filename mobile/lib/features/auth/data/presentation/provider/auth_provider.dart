// manages loading state and error
import 'package:flutter/foundation.dart';
import 'package:mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile/features/auth/domain/usecases/password_reset_usecase.dart';
import 'package:mobile/features/auth/domain/entities/password_reset_request.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
Future<void>? _googleSignInInitialization;

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final PasswordResetUseCase passwordResetUseCase;
  final AuthRepository? authRepository;

  AuthProvider({
    required this.loginUseCase,
    required this.passwordResetUseCase,
    this.authRepository,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  bool get isLoggedIn => authController.isLoggedIn;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
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

      _isLoading = false;
      _isSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Extracts clean error message from ApiExceptions or general exceptions
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
