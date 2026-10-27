//manages loading state and error
import 'package:flutter/foundation.dart';
import 'package:mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;

  AuthProvider({required this.loginUseCase});

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
      final trimmedEmail = email.trim();
      await loginUseCase.execute(trimmedEmail, password);
      await authController.logIn(trimmedEmail, password);
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
