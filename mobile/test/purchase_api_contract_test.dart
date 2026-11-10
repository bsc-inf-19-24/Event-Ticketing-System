import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/api_endpoints.dart';
import 'package:mobile/features/events/event_api.dart';
import 'package:mobile/features/orders/models/order.dart';
import 'package:mobile/features/payment/services/api_payment_service.dart';
import 'package:mobile/features/payment/models/payment_models.dart';
import 'package:mobile/models/ticket.dart';

void main() {
  test(
    'creates order with backend items request and authoritative total',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, ApiEndpoints.orders);
        expect(jsonDecode(request.body), {
          'eventId': 42,
          'items': [
            {'ticketTypeId': 101, 'quantity': 2},
          ],
        });
        return http.Response(
          jsonEncode({
            'id': 501,
            'totalAmount': '35000.00',
            'status': 'PENDING',
            'items': [],
          }),
          201,
        );
      });
      final service = ApiPaymentService(
        apiClient: ApiClient(baseUrl: 'https://api.test', client: client),
      );
      final result = await service.createOrder(
        eventId: '42',
        items: const [
          OrderItem(
            ticketTypeId: '101',
            ticketTypeName: 'Standard',
            unitPrice: 17500,
            quantity: 2,
          ),
        ],
        idempotencyKey: 'unused-client-only-key',
      );
      expect(result['id'], 501);
      expect(Order.fromJson(result).total, 35000);
    },
  );

  test(
    'checkout and verify use exact backend paths and payload shapes',
    () async {
      final calls = <String, Map<String, dynamic>>{};
      final service = ApiPaymentService(
        apiClient: ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient((request) async {
            calls[request.url.path] = request.body.isEmpty
                ? <String, dynamic>{}
                : jsonDecode(request.body) as Map<String, dynamic>;
            if (request.url.path == ApiEndpoints.paymentCheckout) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'checkoutUrl': 'https://pay.test/session',
                    'txRef': 'tx-1',
                    'amount': 35000,
                    'currency': 'MWK',
                    'status': 'PENDING',
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'order': {'status': 'PENDING'},
                'paymentStatus': 'PENDING',
              }),
              200,
            );
          }),
        ),
      );
      final session = await service.initiateOrderPayment(
        orderId: '501',
        method: PaymentMethod.card,
        phone: '',
      );
      expect(session.txRef, 'tx-1');
      expect(calls[ApiEndpoints.paymentCheckout], {'orderId': 501});
      final verified = await service.verifyOrder('501');
      expect(calls[ApiEndpoints.paymentVerify], {'orderId': 501});
      expect(verified['paymentStatus'], 'PENDING');
    },
  );

  test(
    'event API parses local date-time, relative image, inventory and status',
    () async {
      final api = EventApi(
        client: ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient(
            (request) async => http.Response(
              jsonEncode([
                {
                  'id': 42,
                  'name': 'Festival',
                  'date': '2026-12-05T15:00:00',
                  'venue': 'BICC',
                  'coverImagePath': '/images/event.jpg',
                  'status': 'AVAILABLE',
                  'ticketTypes': [
                    {
                      'id': 101,
                      'name': 'Standard',
                      'price': 17500,
                      'remainingInventory': 0,
                    },
                  ],
                },
              ]),
              200,
            ),
          ),
        ),
      );
      final event = (await api.list()).single;
      expect(event.id, '42');
      expect(event.time, '3:00 PM');
      expect(event.imagePath, 'https://api.test/images/event.jpg');
      expect(event.ticketTypes.single.remainingInventory, 0);
      expect(event.ticketTypes.single.isAvailable, isFalse);
    },
  );

  test(
    'published events and active ticket types are available for purchase',
    () async {
      final api = EventApi(
        client: ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode([
                {
                  'id': 42,
                  'name': 'Published festival',
                  'status': 'PUBLISHED',
                  'ticketTypes': [
                    {
                      'id': 101,
                      'name': 'Standard',
                      'price': 17500,
                      'status': 'ACTIVE',
                      'availableQuantity': 4,
                    },
                  ],
                },
              ]),
              200,
            ),
          ),
        ),
      );

      final event = (await api.list()).single;
      expect(event.isAvailable, isTrue);
      expect(event.ticketTypes.single.isAvailable, isTrue);
      expect(event.ticketTypes.single.remainingInventory, 4);
    },
  );

  test(
    'event API returns an empty list when the server has no events',
    () async {
      final api = EventApi(
        client: ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient((_) async => http.Response('[]', 200)),
        ),
      );

      expect(await api.list(), isEmpty);
    },
  );

  test('ticket QR content is read verbatim from qrContent', () {
    const qr = 'signed|payload:do-not-normalize';
    final ticket = Ticket.fromServer({
      'id': 99,
      'ticketCode': 'T-99',
      'qrContent': qr,
      'status': 'ISSUED',
      'event': {'name': 'Festival'},
    }, authenticatedUserId: 'customer-1');
    expect(ticket.qrPayload, qr);
    expect(ticket.source, 'server');
  });
}
