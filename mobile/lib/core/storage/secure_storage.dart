import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _legacyTokenKey = 'auth_token';

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) return token;

    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(_legacyTokenKey);
    if (legacyToken == null) return null;

    await saveToken(legacyToken);
    await preferences.remove(_legacyTokenKey);
    return legacyToken;
  }

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyTokenKey);
  }

  Future<void> deleteToken() => clearTokens();
}
