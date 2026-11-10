import 'package:flutter/widgets.dart';

/// Interprets a backend-configured app redirect; gateway fields are diagnostic only.
class PaymentReturnHandler with WidgetsBindingObserver {
  PaymentReturnHandler({
    required this.onReturn,
    this.redirectUri = 'myapp://payment-result',
  });

  final Future<void> Function(String orderId, {String? status, String? txRef})
  onReturn;
  final String redirectUri;
  String? _pendingOrderId;
  bool _handling = false;

  String? get pendingOrderId => _pendingOrderId;

  void preserveOrder(String orderId) {
    if (orderId.trim().isNotEmpty) _pendingOrderId = orderId;
  }

  Future<bool> handle(Uri uri) async {
    final configured = Uri.parse(redirectUri);
    if (uri.scheme != configured.scheme ||
        uri.host != configured.host ||
        uri.path != configured.path ||
        _handling) {
      return false;
    }
    final orderId = uri.queryParameters['orderId'] ?? _pendingOrderId;
    if (orderId == null || orderId.isEmpty) return false;
    if (uri.queryParameters['orderId'] != null) _pendingOrderId = orderId;
    _handling = true;
    try {
      await onReturn(
        orderId,
        status: uri.queryParameters['status'],
        txRef: uri.queryParameters['tx_ref'] ?? uri.queryParameters['txRef'],
      );
    } finally {
      _handling = false;
    }
    return true;
  }
}
