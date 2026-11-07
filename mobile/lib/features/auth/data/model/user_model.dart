//JSON serialization for user/Token
import '/features/auth/domain/entities/user.dart';

class UserModel extends User {
  final String token;
  final String refreshToken;

  const UserModel({
    required super.id,
    required super.email,
    required this.token,
    this.refreshToken = '',
    super.name = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : data;
    return UserModel(
      id: user['id']?.toString() ?? user['userId']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      token: data['token']?.toString() ?? data['accessToken']?.toString() ?? '',
      refreshToken: data['refreshToken']?.toString() ?? '',
      name:
          user['name']?.toString() ??
          user['fullName']?.toString() ??
          user['full_name']?.toString() ??
          '',
    );
  }

  // Maps the data-layer model into the pure domain entity
  User toDomain() {
    return User(id: id, email: email, name: name);
  }
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

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
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }
}
