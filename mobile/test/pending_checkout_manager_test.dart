import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/storage/pending_checkout_store.dart';
import 'package:mobile/features/payment/services/api_payment_service.dart';
import 'package:mobile/features/payment/services/pending_checkout_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PAID clears scoped pending state and refreshes tickets', () async {
    final store = PendingCheckoutStore();
    await store.save('order-a', userId: 'user-a');
    var refreshes = 0;
    final manager = _manager(
      store: store,
      handler: (_) async => http.Response('{"status":"PAID"}', 200),
      refresh: () async => refreshes++,
    );
    final pending = (await store.read(userId: 'user-a'))!;
    expect(
      await manager.check(pending, userId: 'user-a'),
      PendingCheckoutResolution.paid,
    );
    expect(await store.read(userId: 'user-a'), isNull);
    expect(refreshes, 1);
  });

  test(
    'CANCELLED and 404 clear; old records expire without a request',
    () async {
      final store = PendingCheckoutStore();
      await store.save('order-a', userId: 'user-a');
      final cancelled = _manager(
        store: store,
        handler: (_) async => http.Response('{"status":"CANCELLED"}', 200),
      );
      expect(
        await cancelled.check(
          (await store.read(userId: 'user-a'))!,
          userId: 'user-a',
        ),
        PendingCheckoutResolution.cleared,
      );
      expect(await store.read(userId: 'user-a'), isNull);

      await store.save('order-404', userId: 'user-a');
      final missing = _manager(
        store: store,
        handler: (_) async => http.Response('{"message":"missing"}', 404),
      );
      expect(
        await missing.check(
          (await store.read(userId: 'user-a'))!,
          userId: 'user-a',
        ),
        PendingCheckoutResolution.cleared,
      );

      await store.save(
        'old-order',
        userId: 'user-a',
        now: DateTime(2026, 1, 1),
      );
      var calls = 0;
      final expired = _manager(
        store: store,
        clock: () => DateTime(2026, 1, 1, 0, 31),
        handler: (_) async {
          calls++;
          return http.Response('{}', 500);
        },
      );
      expect(
        await expired.check(
          (await store.read(userId: 'user-a'))!,
          userId: 'user-a',
        ),
        PendingCheckoutResolution.cleared,
      );
      expect(calls, 0);
      expect(await store.read(userId: 'user-a'), isNull);
    },
  );

  test('recent PENDING remains private and Verify posts orderId', () async {
    final store = PendingCheckoutStore();
    await store.save('order-a', userId: 'user-a');
    http.Request? verificationRequest;
    final manager = _manager(
      store: store,
      handler: (request) async {
        if (request.method == 'POST') {
          verificationRequest = request;
          return http.Response('{"status":"PAID"}', 200);
        }
        return http.Response('{"status":"PENDING"}', 200);
      },
    );
    final pending = (await store.read(userId: 'user-a'))!;
    expect(
      await manager.check(pending, userId: 'user-a'),
      PendingCheckoutResolution.pending,
    );
    expect(await store.read(userId: 'user-b'), isNull);
    expect(
      await manager.verify(pending, userId: 'user-a'),
      PendingCheckoutResolution.paid,
    );
    expect(verificationRequest!.url.path, '/api/payments/verify');
    expect(jsonDecode(verificationRequest!.body), {'orderId': 'order-a'});
    expect(await store.read(userId: 'user-a'), isNull);
  });

  test(
    'network failures preserve the pending record without raising an error',
    () async {
      final store = PendingCheckoutStore();
      await store.save('order-a', userId: 'user-a');
      final manager = _manager(
        store: store,
        handler: (_) async => throw http.ClientException('offline'),
      );
      expect(
        await manager.check(
          (await store.read(userId: 'user-a'))!,
          userId: 'user-a',
        ),
        PendingCheckoutResolution.unavailable,
      );
      expect((await store.read(userId: 'user-a'))?.orderId, 'order-a');
    },
  );
}

PendingCheckoutManager _manager({
  required PendingCheckoutStore store,
  required Future<http.Response> Function(http.Request) handler,
  Future<void> Function()? refresh,
  DateTime Function()? clock,
}) => PendingCheckoutManager(
  api: ApiPaymentService(
    apiClient: ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient(handler),
    ),
  ),
  store: store,
  refreshTickets: refresh,
  clock: clock,
);
