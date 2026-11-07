class UserModel {
  final String email;
  final String? avatarUrl;

  const UserModel({required this.email, this.avatarUrl});

  // Factory to convert JSON/API response to a UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : json;
    return UserModel(
      email: profile['email']?.toString() ?? '',
      avatarUrl: profile['avatarUrl']?.toString(),
    );
  }
}
