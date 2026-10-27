//JSON serialization for user/Token
import '/features/auth/domain/entities/user.dart';

class UserModel extends User {
  final String token;

  const UserModel({
    required String id,
    required String email,
    required this.token,
  }) : super(id: id, email: email);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? json['accessToken'] ?? '',
    );
  }

  // Maps the data-layer model into the pure domain entity
  User toDomain() {
    return User(
      id: id,
      email: email,
    );
  }
}