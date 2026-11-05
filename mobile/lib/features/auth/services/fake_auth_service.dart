import 'dart:math';

import 'package:mobile/features/auth/models/app_user.dart';

import 'auth_service.dart';

/// An in-memory authentication service for demo use.
class FakeAuthService implements AuthService {
  /// Creates a service seeded with the demo account.
  FakeAuthService({
    DateTime Function()? clock,
    String Function()? resetCodeGenerator,
  }) : _passwords = {
         'demo@ticketmaster.mw': 'demo1234',
         'test.customer@example.com': 'SecurePassword123!',
         'admin@example.com': 'password123',
       },
       _users = {
         'demo@ticketmaster.mw': const AppUser(
           id: 'U-001',
           name: 'Demo User',
           email: 'demo@ticketmaster.mw',
         ),
         'test.customer@example.com': const AppUser(
           id: 'U-002',
           name: 'Test Customer',
           email: 'test.customer@example.com',
         ),
         'admin@example.com': const AppUser(
           id: 'U-003',
           name: 'Admin User',
           email: 'admin@example.com',
         ),
       },
       _clock = clock ?? DateTime.now,
       _resetCodeGenerator = resetCodeGenerator ?? _generateResetCode;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _resetCodeLifetime = Duration(minutes: 10);

  final Map<String, String> _passwords;
  final Map<String, AppUser> _users;
  final Map<String, _PasswordResetCode> _passwordResetCodes = {};
  final DateTime Function() _clock;
  final String Function() _resetCodeGenerator;
  int _nextUserNumber = 4;

  static String _generateResetCode() =>
      Random.secure().nextInt(1000000).toString().padLeft(6, '0');

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

  @override
  Future<String> requestPasswordReset({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    if (!_users.containsKey(normalizedEmail)) {
      throw const AuthException('No account was found for this email address.');
    }

    final code = _resetCodeGenerator();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const AuthException('Could not create a verification code.');
    }

    _passwordResetCodes[normalizedEmail] = _PasswordResetCode(
      code: code,
      expiresAt: _clock().add(_resetCodeLifetime),
    );
    return code;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    if (!_users.containsKey(normalizedEmail)) {
      throw const AuthException('No account was found for this email address.');
    }
    if (newPassword.length < 7 ||
        !RegExp(r'[A-Za-z]').hasMatch(newPassword) ||
        !RegExp(r'\d').hasMatch(newPassword) ||
        !RegExp(r'[^A-Za-z0-9\s]').hasMatch(newPassword)) {
      throw const AuthException(
        'Password must be at least 7 characters and include a letter, a number, and a symbol.',
      );
    }

    final resetCode = _passwordResetCodes[normalizedEmail];
    if (resetCode == null || !_clock().isBefore(resetCode.expiresAt)) {
      _passwordResetCodes.remove(normalizedEmail);
      throw const AuthException(
        'Verification code has expired. Request a new one.',
      );
    }
    if (resetCode.code != code.trim()) {
      throw const AuthException(
        'Incorrect verification code. Please try again.',
      );
    }

    _passwords[normalizedEmail] = newPassword;
    _passwordResetCodes.remove(normalizedEmail);
  }
}

class _PasswordResetCode {
  const _PasswordResetCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}
