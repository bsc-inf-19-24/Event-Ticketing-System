import 'package:mobile/core/storage/secure_storage.dart';

class TokenStorage {
  final _storage = SecureStorageService();

  Future<void> save(String token) => _storage.saveToken(token);
  Future<String?> read() => _storage.getToken();
  Future<void> clear() => _storage.deleteToken();
}
