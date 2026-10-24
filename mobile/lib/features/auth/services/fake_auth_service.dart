import 'package:mobile/features/auth/models/app_user.dart';
import 'auth_service.dart';

/// An in-memory authentication service for demo use.
class FakeAuthService implements AuthService {
  /// Creates a service seeded with the demo account.
  FakeAuthService()
    : _passwords = {'demo@ticketmaster.mw': 'demo1234'},
      _users = {
        'demo@ticketmaster.mw': const AppUser(
          id: 'U-001',
          name: 'Demo User',
          email: 'demo@ticketmaster.mw',
        ),
      };

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final Map<String, String> _passwords;
  final Map<String, AppUser> _users;
  int _nextUserNumber = 2;

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (name.trim().isEmpty) {
      throw const AuthException('Name must not be empty.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    if (password.length < 8) {
      throw const AuthException('Password must be at least 8 characters.');
    }

    if (_users.containsKey(normalizedEmail)) {
      throw const AuthException('An account with this email already exists.');
    }

    final user = AppUser(
      id: 'U-${_nextUserNumber.toString().padLeft(3, '0')}',
      name: name.trim(),
      email: normalizedEmail,
    );
    _nextUserNumber++;

    _passwords[normalizedEmail] = password;
    _users[normalizedEmail] = user;

    return user;
  }

  @override
  Future<AppUser> logIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final normalizedEmail = email.trim().toLowerCase();
    final user = _users[normalizedEmail];
    if (user == null || _passwords[normalizedEmail] != password) {
      throw const AuthException('Incorrect email or password.');
    }

    return user;
  }
}
