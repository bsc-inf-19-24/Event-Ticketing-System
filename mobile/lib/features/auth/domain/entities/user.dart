//pure dart entity
class User {
  final String id;
  final String email;
  final String? name;
  final String role;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.role = '',
  });
}
