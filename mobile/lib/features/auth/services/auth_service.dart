import 'package:mobile/features/auth/models/app_user.dart';

/// An authentication operation failed.
class AuthException implements Exception {
  /// Creates an authentication exception with a user-facing message.
  const AuthException(this.message);

  /// A user-facing description of the authentication failure.
  final String message;

  @override
  String toString() => message;
}

/// Defines the operations provided by an authentication service.
abstract class AuthService {
  /// Creates an account and returns its user.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Authenticates an account and returns its user.
  Future<AppUser> logIn({required String email, required String password});
}
