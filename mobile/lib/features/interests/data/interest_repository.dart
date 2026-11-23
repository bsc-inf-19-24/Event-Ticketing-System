import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/api_endpoints.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../models/event.dart';
import '../models/interest.dart';

class InterestRepository {
  InterestRepository({ApiClient? apiClient, this._preferences})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String get _cacheUserKey {
    final userId = authController.stableUserId;
    return 'customer_interests_${userId ?? 'anonymous'}';
  }

  String get _catalogCacheKey => 'customer_interest_catalog';

  Future<List<Interest>> fetchCatalog({bool cacheOnly = false}) async {
    if (cacheOnly) return _readCatalogCache();
    final response = await _apiClient.get(ApiEndpoints.interests);
    final catalog = _listResponse(response)
        .map((value) => Interest.fromJson(value))
        .toList();
    await _writeCatalogCache(catalog);
    return catalog;
  }

  Future<List<CustomerInterest>> fetchMyInterests({
    bool cacheOnly = false,
  }) async {
    if (cacheOnly) return _readSelectionCache();
    final response = await _apiClient.get(ApiEndpoints.myInterests);
    final selections = _listResponse(response)
        .map((value) => CustomerInterest.fromJson(value))
        .toList();
    await _writeSelectionCache(selections);
    return selections;
  }

  Future<CustomerInterest> addInterest(int interestId) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.addMyInterest}?interestId=$interestId',
      null,
    );
    if (response is! Map) {
      throw const ApiException(
        'The server returned an invalid interest response.',
      );
    }
    final added = CustomerInterest.fromJson(
      Map<String, dynamic>.from(response),
    );
    final cached = await _readSelectionCache();
    if (!cached.any((value) => value.interest.id == interestId)) {
      await _writeSelectionCache([...cached, added]);
    }
    try {
      await fetchMyInterests();
    } catch (_) {
      // The add is already confirmed. A follow-up refresh can be retried later.
    }
    return added;
  }

  Future<void> removeInterest(int interestId) async {
    await _apiClient.delete(ApiEndpoints.myInterest(interestId));
    final cached = await _readSelectionCache();
    await _writeSelectionCache(
      cached.where((value) => value.interest.id != interestId).toList(),
    );
    try {
      await fetchMyInterests();
    } catch (_) {
      // The delete is already confirmed. A follow-up refresh can be retried later.
    }
  }

  Future<void> reconcile(List<CustomerInterest> selections) =>
      _writeSelectionCache(selections);

  Future<void> trackCategoryView(String category) async {
    await _recordActivity(category, purchase: false);
  }

  Future<void> trackCategoryPurchase(String category) async {
    await _recordActivity(category, purchase: true);
  }

  Future<List<Event>> personalizeEvents(List<Event> events) async {
    final selected = await fetchMyInterests(cacheOnly: true);
    final activity = await _readActivity();
    final scores = _categoryScores(selected, activity);
    final ranked = [...events];
    ranked.sort((a, b) {
      final aScore = scores[_normalizeCategory(a.category)];
      final bScore = scores[_normalizeCategory(b.category)];
      return (bScore ?? 0).compareTo(aScore ?? 0);
    });
    return ranked;
  }

  Future<bool> ensureInterestForCategory(String category) async {
    final interestName = _interestNameForCategory(category);
    if (interestName == null) return false;
    final catalog = await fetchCatalog();
    final matching = catalog
        .where(
          (value) =>
              _normalizeCategory(value.name) ==
              _normalizeCategory(interestName),
        )
        .toList();
    if (matching.isEmpty) return false;
    final selected = await fetchMyInterests();
    if (selected.any((value) => value.interest.id == matching.first.id)) {
      return false;
    }
    await addInterest(matching.first.id);
    return true;
  }

  Future<void> _recordActivity(
    String category, {
    required bool purchase,
  }) async {
    final normalized = _normalizeCategory(category);
    if (normalized.isEmpty) return;
    final activity = await _readActivity();
    activity[normalized] = (activity[normalized] ?? 0) + (purchase ? 5 : 1);
    await (await _prefs).setString(
      '$_activityKeyPrefix$_cacheUserKey',
      jsonEncode(activity),
    );
    try {
      await ensureInterestForCategory(category);
    } catch (_) {
      // Browsing or buying must remain usable when interest synchronization fails.
    }
  }

  String get _activityKeyPrefix => 'customer_interest_activity_';

  Future<Map<String, int>> _readActivity() async {
    final raw = (await _prefs).getString('$_activityKeyPrefix$_cacheUserKey');
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  Map<String, int> _categoryScores(
    List<CustomerInterest> selected,
    Map<String, int> activity,
  ) {
    final scores = <String, int>{};
    for (final selection in selected) {
      final category = _normalizeCategory(selection.interest.name);
      if (category.isNotEmpty) {
        scores[category] = (scores[category] ?? 0) + 100;
      }
    }
    for (final entry in activity.entries) {
      scores[entry.key] = (scores[entry.key] ?? 0) + entry.value * 3;
    }
    return scores;
  }

  String? _interestNameForCategory(String category) {
    switch (_normalizeCategory(category)) {
      case 'music':
      case 'concert':
      case 'concerts':
        return 'Music';
      case 'sports':
      case 'sport':
        return 'Sports';
      case 'tech':
      case 'technology':
        return 'Tech';
      case 'community':
      case 'communityevent':
        return 'Community';
      case 'food':
      case 'festival':
        return 'Food';
      case 'art':
      case 'arts':
      case 'workshop':
        return 'Art';
      case 'fitness':
        return 'Fitness';
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _listResponse(dynamic response) {
    if (response is! List) {
      throw const ApiException('The server returned an invalid interest list.');
    }
    return response
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Interest>> _readCatalogCache() async {
    final raw = (await _prefs).getString(_catalogCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    return _decodeInterestList(raw);
  }

  Future<List<CustomerInterest>> _readSelectionCache() async {
    final raw = (await _prefs).getString(_cacheUserKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (value) =>
              CustomerInterest.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList();
  }

  Future<void> _writeCatalogCache(List<Interest> catalog) async {
    final raw = jsonEncode(catalog.map((value) => value.toJson()).toList());
    await (await _prefs).setString(_catalogCacheKey, raw);
  }

  Future<void> _writeSelectionCache(List<CustomerInterest> selections) async {
    final raw = jsonEncode(selections.map((value) => value.toJson()).toList());
    await (await _prefs).setString(_cacheUserKey, raw);
  }

  List<Interest> _decodeInterestList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((value) => Interest.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }
}

String _normalizeCategory(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
