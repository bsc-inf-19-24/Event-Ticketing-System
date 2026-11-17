//JSON serialization for user/Token
import '/features/auth/domain/entities/user.dart';

import 'dart:convert';

class UserModel extends User {
  final String token;
  final String refreshToken;

  const UserModel({
    required super.id,
    required super.email,
    required this.token,
    this.refreshToken = '',
    super.name = '',
    super.role = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final nestedUser = _firstMap(data, const ['user', 'customer', 'profile']);
    final user = nestedUser ?? data;
    final token =
        data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
    final claims = nestedUser == null
        ? _tokenClaims(token)
        : const <String, dynamic>{};
    return UserModel(
      id:
          user['id']?.toString() ??
          user['userId']?.toString() ??
          user['user_id']?.toString() ??
          user['customerId']?.toString() ??
          user['customer_id']?.toString() ??
          '',
      email:
          user['email']?.toString() ??
          user['emailAddress']?.toString() ??
          user['email_address']?.toString() ??
          claims['email']?.toString() ??
          claims['sub']?.toString() ??
          '',
      token: token,
      refreshToken: data['refreshToken']?.toString() ?? '',
      name:
          user['name']?.toString() ??
          user['fullName']?.toString() ??
          user['full_name']?.toString() ??
          '',
      role: user['role']?.toString() ?? user['userRole']?.toString() ?? '',
    );
  }

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (source[key] is Map) {
        return Map<String, dynamic>.from(source[key] as Map);
      }
    }
    return null;
  }

  static Map<String, dynamic> _tokenClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } on FormatException {
      return const {};
    }
  }

  // Maps the data-layer model into the pure domain entity
  User toDomain() {
    return User(id: id, email: email, name: name, role: role);
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel? user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final accessToken =
        data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const FormatException(
        'The server did not return both authentication tokens.',
      );
    }
    final user = data['user'] is Map
        ? UserModel.fromJson({'data': data})
        : null;
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }
}
