//JSON serialization for user/Token
import '/features/auth/domain/entities/user.dart';

class UserModel extends User {
  final String token;
  final String name;

  const UserModel({
    required super.id,
    required super.email,
    super.name,
    required this.token,
    this.name = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] as String?,
      token: json['token'] ?? json['accessToken'] ?? '',
      name: json['name']?.toString() ?? json['full_name']?.toString() ?? '',
    );
  }

  // Maps the data-layer model into the pure domain entity
  User toDomain() {
    return User(id: id, email: email, name: name);
  }
}
