import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/api_endpoints.dart';
import 'package:mobile/features/payment/services/api_payment_service.dart';
import 'package:mobile/services/ticket_repository.dart';
import 'package:mobile/services/ticket_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'loads issued tickets from paid orders and keeps them available offline',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, ApiEndpoints.myOrders);
        return http.Response(
          jsonEncode({
            'data': {
              'orders': [
                {
                  'id': 'order-1',
                  'status': 'paid',
                  'tickets': [
                    {
                      'id': 'ticket-1',
                      'userId': 'customer-1',
                      'eventName': 'Festival',
                      'date': '2027-01-01',
                      'venue': 'Lilongwe',
                      'ticketType': 'VIP',
                      'status': 'Issued',
                      'paymentStatus': 'Paid',
                      'qrCode': 'server-signed-qr',
                    },
                  ],
                },
                {
                  'id': 'order-pending',
                  'status': 'pending',
                  'tickets': [
                    {'id': 'ticket-pending', 'userId': 'customer-1'},
                  ],
                },
              ],
            },
          }),
          200,
        );
      });
      final storage = TicketStorage(databasePath: ':memory:');
      final api = ApiPaymentService(
        apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client)
          ..tokenProvider = () async => 'access-token',
      );
      final repository = TicketRepository(storage: storage, ordersApi: api);

      final online = await repository.load(
        userId: 'customer-1',
        hasConnection: true,
      );
      expect(online.tickets, hasLength(1));
      expect(online.tickets.single.id, 'ticket-1');
      expect(online.tickets.single.source, 'server');
      expect(online.tickets.single.qrPayload, 'server-signed-qr');

      final offline = await repository.load(
        userId: 'customer-1',
        hasConnection: false,
      );
      expect(offline.isOffline, isTrue);
      expect(offline.tickets.single.qrPayload, 'server-signed-qr');
      expect(await storage.getSavedTickets(userId: 'other-user'), isEmpty);

      await storage.close();
    },
  );

  test('rejects tickets in another customer account response', () async {
    final api = ApiPaymentService(
      apiClient: ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'order-1',
                  'status': 'paid',
                  'tickets': [
                    {'id': 'ticket-1', 'userId': 'customer-2'},
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      )..tokenProvider = () async => 'access-token',
    );
    final storage = TicketStorage(databasePath: ':memory:');
    final repository = TicketRepository(storage: storage, ordersApi: api);

    await expectLater(
      repository.load(userId: 'customer-1', hasConnection: true),
      throwsA(isA<ApiException>()),
    );
    expect(await storage.getSavedTickets(userId: 'customer-1'), isEmpty);

    await storage.close();
  });
}
