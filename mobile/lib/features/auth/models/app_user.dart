/// Represents an authenticated user without storing sensitive credentials.
class AppUser {
  /// Creates an authenticated user.
  const AppUser({required this.id, required this.name, required this.email});

  /// The user's unique identifier.
  final String id;

  /// The user's display name.
  final String name;

  /// The user's email address.
  final String email;

  /// Converts this user to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  /// Creates a user from a JSON-compatible map.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}
