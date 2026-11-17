import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_scope.dart';

class PendingCheckout {
  const PendingCheckout({required this.orderId, required this.createdAt});
  final String orderId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingCheckout.fromJson(Map<String, dynamic> json) =>
      PendingCheckout(
        orderId: json['orderId']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class PendingCheckoutStore {
  Future<PendingCheckout?> read({String? userId}) async {
    final key = _key(userId);
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map
          ? PendingCheckout.fromJson(Map<String, dynamic>.from(value))
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String orderId, {String? userId, DateTime? now}) async {
    final key = _key(userId);
    if (key == null || orderId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final scope = userId ?? StorageScope.currentKey();
    final existing = await read(userId: scope);
    final createdAt = existing?.orderId == orderId
        ? existing!.createdAt
        : now ?? DateTime.now();
    await prefs.setString(
      key,
      jsonEncode(
        PendingCheckout(orderId: orderId, createdAt: createdAt).toJson(),
      ),
    );
  }

  Future<void> clear({String? userId}) async {
    final key = _key(userId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  String? _key(String? userId) {
    return StorageScope.key('pending_checkout', userId: userId);
  }
}
