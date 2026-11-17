import 'package:mobile/features/auth/logic/auth_controller.dart';

/// Namespaces all customer-owned local data by the authenticated account.
class StorageScope {
  const StorageScope._();

  static String? currentKey({AuthController? auth}) {
    final user = (auth ?? authController).user;
    if (user == null) return null;
    return keyForUser(user.id, user.email);
  }

  static String? keyForUser(String id, String email) {
    final trimmedId = id.trim();
    if (trimmedId.isNotEmpty) return trimmedId;
    final normalizedEmail = email.trim().toLowerCase();
    return normalizedEmail.isEmpty ? null : normalizedEmail;
  }

  static String? key(String prefix, {String? userId, AuthController? auth}) {
    final explicitScope = userId?.trim();
    final scope = explicitScope == null
        ? currentKey(auth: auth)
        : explicitScope.isEmpty
        ? null
        : explicitScope;
    return scope == null ? null : '$prefix:$scope';
  }
}
