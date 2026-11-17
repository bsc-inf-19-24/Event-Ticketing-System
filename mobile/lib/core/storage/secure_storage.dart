import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/models/app_user.dart';

import 'storage_scope.dart';

class SecureStorageService {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _legacyTokenKey = 'auth_token';
  static const _userKeyPrefix = 'auth_app_user';
  static const _activeUserKey = 'auth_active_user_key';

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> deleteToken() => clearTokens();

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

  Future<void> saveUser(AppUser user) async {
    final scope = StorageScope.keyForUser(user.id, user.email);
    if (scope == null || scope.isEmpty) return;
    final userKey = '$_userKeyPrefix:$scope';
    await _storage.write(key: userKey, value: jsonEncode(user.toJson()));
    await _storage.write(key: _activeUserKey, value: userKey);
  }

  Future<AppUser?> getUser() async {
    final userKey = await _storage.read(key: _activeUserKey);
    if (userKey == null) return null;
    final raw = await _storage.read(key: userKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(data))
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

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
    final userKey = await _storage.read(key: _activeUserKey);
    if (userKey != null) await _storage.delete(key: userKey);
    await _storage.delete(key: _activeUserKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyTokenKey);
  }
}
