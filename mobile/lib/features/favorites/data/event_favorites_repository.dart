import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/logic/auth_controller.dart';

class EventFavoritesRepository {
  EventFavoritesRepository({this._preferences});

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String get _key {
    final userId = authController.stableUserId;
    return 'event_favorites_${userId ?? 'anonymous'}';
  }

  Future<Set<String>> getFavoriteIds() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.map((value) => value.toString()).toSet();
  }

  Future<bool> isFavorite(String eventId) async =>
      (await getFavoriteIds()).contains(eventId);

  Future<bool> toggleFavorite(String eventId) async {
    final favorites = await getFavoriteIds();
    final exists = favorites.remove(eventId);
    if (!exists) favorites.add(eventId);
    await (await _prefs).setString(_key, jsonEncode(favorites.toList()));
    return !exists;
  }
}
