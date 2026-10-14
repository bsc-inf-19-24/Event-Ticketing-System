class UserModel {
  final String email;
  final String? avatarUrl;

  const UserModel({
    required this.email,
    this.avatarUrl,
  });

  // Factory to convert JSON/API response to a UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'] ?? 'example@gmail.com',
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }
}