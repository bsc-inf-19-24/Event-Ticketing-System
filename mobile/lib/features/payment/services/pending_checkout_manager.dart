import '../../../core/api_client.dart';
import '../../../core/storage/pending_checkout_store.dart';
import '../../../features/tickets/logic/tickets_controller.dart';
import 'api_payment_service.dart';

enum PendingCheckoutResolution { paid, pending, cleared, unavailable }

class PendingCheckoutManager {
  PendingCheckoutManager({
    ApiPaymentService? api,
    PendingCheckoutStore? store,
    Future<void> Function()? refreshTickets,
    DateTime Function()? clock,
  }) : _api = api ?? ApiPaymentService(),
       _store = store ?? PendingCheckoutStore(),
       _refreshTickets = refreshTickets ?? ticketsController.load,
       _clock = clock ?? DateTime.now;

  final ApiPaymentService _api;
  final PendingCheckoutStore _store;
  final Future<void> Function() _refreshTickets;
  final DateTime Function() _clock;

  Future<PendingCheckoutResolution> check(
    PendingCheckout pending, {
    required String userId,
  }) async {
    if (_clock().difference(pending.createdAt) > const Duration(minutes: 30)) {
      await _store.clear(userId: userId);
      return PendingCheckoutResolution.cleared;
    }
    try {
      final order = await _api.getOrder(pending.orderId);
      return await _applyStatus(_status(order), userId: userId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        await _store.clear(userId: userId);
        return PendingCheckoutResolution.cleared;
      }
      return PendingCheckoutResolution.unavailable;
    } catch (_) {
      return PendingCheckoutResolution.unavailable;
    }
  }

  Future<PendingCheckoutResolution> verify(
    PendingCheckout pending, {
    required String userId,
  }) async {
    try {
      final response = await _api.verifyOrder(pending.orderId);
      final resolution = await _applyStatus(_status(response), userId: userId);
      if (resolution == PendingCheckoutResolution.unavailable) {
        return await check(pending, userId: userId);
      }
      return resolution;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        await _store.clear(userId: userId);
        return PendingCheckoutResolution.cleared;
      }
      return PendingCheckoutResolution.unavailable;
    } catch (_) {
      return PendingCheckoutResolution.unavailable;
    }
  }

  Future<PendingCheckoutResolution> _applyStatus(
    String status, {
    required String userId,
  }) async {
    if (status == 'PAID' ||
        status == 'SUCCESS' ||
        status == 'SUCCESSFUL' ||
        status == 'COMPLETED' ||
        status == 'SETTLED') {
      await _store.clear(userId: userId);
      try {
        await _refreshTickets();
      } catch (_) {
        // A paid order remains confirmed when ticket refresh is offline.
      }
      return PendingCheckoutResolution.paid;
    }
    if (const {'CANCELLED', 'CANCELED', 'FAILED'}.contains(status)) {
      await _store.clear(userId: userId);
      return PendingCheckoutResolution.cleared;
    }
    if (status == 'PENDING') return PendingCheckoutResolution.pending;
    return PendingCheckoutResolution.unavailable;
  }

  String _status(Map<String, dynamic> value) {
    final order = value['order'] is Map
        ? Map<String, dynamic>.from(value['order'] as Map)
        : const <String, dynamic>{};
    final payment = value['payment'] is Map
        ? Map<String, dynamic>.from(value['payment'] as Map)
        : const <String, dynamic>{};
    return (value['status'] ??
            value['orderStatus'] ??
            value['order_status'] ??
            value['paymentStatus'] ??
            value['payment_status'] ??
            order['status'] ??
            payment['status'] ??
            '')
        .toString()
        .toUpperCase();
  }
}
