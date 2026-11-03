import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/fake_auth_service.dart';

/// Coordinates authentication state for the application.
class AuthController extends ChangeNotifier {
  /// Creates a controller backed by the provided authentication service.
  AuthController(this._authService);

  final AuthService _authService;
  AppUser? _user;
  bool _isBusy = false;

  /// The currently authenticated user, if any.
  AppUser? get user => _user;

  /// Whether a user is currently authenticated.
  bool get isLoggedIn => _user != null;

  /// Whether an authentication operation is in progress.
  bool get isBusy => _isBusy;

  /// Creates an account and signs the new user in.
  Future<void> signUp(String name, String email, String password) async {
    _isBusy = true;
    notifyListeners();

    try {
      _user = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );
      notifyListeners();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Signs in an existing user.
  Future<void> logIn(String email, String password) async {
    _isBusy = true;
    notifyListeners();

    try {
      _user = await _authService.logIn(email: email, password: password);
      notifyListeners();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Signs out the current user.
  void logOut() {
    _user = null;
    notifyListeners();
  }
}

// Share the demo accounts between the app login flow and auth state.
final fakeAuthService = FakeAuthService();
final authController = AuthController(fakeAuthService);
