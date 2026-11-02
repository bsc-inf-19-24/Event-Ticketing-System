import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'auth_service.dart';
import 'token_storage.dart';

class ApiAuthService implements AuthService {
  ApiAuthService({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
  });

  final String baseUrl;
  final _tokens = TokenStorage();

  @override
  Future<AppUser> logIn({
    required String email,
    required String password,
  }) async {
    final body = await _post('/api/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return _finish(body, email, fallbackName: '');
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final body = await _post('/api/auth/register', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': 'CUSTOMER',
    });
    final user = await _finish(body, email, fallbackName: name.trim());

    // The API has no name in register, so send it to the profile endpoint.
    // TODO: confirm with backend (or ask them to accept "name" in register).
    await _saveName(name.trim());
    return user;
  }

  Future<AppUser> _finish(
    Map<String, dynamic> body,
    String email, {
    required String fallbackName,
  }) async {
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('Unexpected response from the server.');
    }
    await _tokens.save(token);

    // ASSUMPTION: the response may or may not include a "user" object.
    final userJson = body['user'];
    if (userJson is Map<String, dynamic>) {
      return AppUser(
        id: '${userJson['id'] ?? ''}',
        name:
            (userJson['fullName'] ?? userJson['name'] ?? fallbackName)
                as String,
        email: (userJson['email'] ?? email) as String,
      );
    }
    return AppUser(id: '', name: fallbackName, email: email.trim());
  }

  Future<void> _saveName(String name) async {
    if (name.isEmpty) return;
    final token = await _tokens.read();
    if (token == null) return;
    try {
      await http
          .put(
            Uri.parse('$baseUrl/api/customers/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'fullName': name}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Not critical: the account exists, the name can be saved later.
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Could not reach the server. Check your internet connection.',
      );
    }

    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    // ASSUMPTION: errors carry a "message" field. Confirm the real format.
    final serverMessage = json['message'] as String?;
    switch (response.statusCode) {
      case 401:
        throw AuthException('Incorrect email or password.');
      case 409:
        throw AuthException('An account with this email already exists.');
      case 400:
        throw AuthException(serverMessage ?? 'Please check your details.');
      default:
        throw AuthException(
          serverMessage ?? 'Something went wrong. Try again.',
        );
    }
  }
}
