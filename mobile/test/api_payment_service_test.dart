import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/api_endpoints.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/orders/models/order.dart';
import 'package:mobile/features/orders/services/order_repository.dart';
import 'package:mobile/features/payment/logic/payment_controller.dart';
import 'package:mobile/features/payment/models/payment_models.dart';
import 'package:mobile/features/payment/services/api_payment_service.dart';
import 'package:mobile/features/payment/services/payment_service.dart';
import 'package:mobile/features/tickets/logic/tickets_controller.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'order creation sends IDs, quantity, and an idempotency key only',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, ApiEndpoints.orders);
        expect(request.headers['Idempotency-Key'], 'retry-key-1');
        expect(request.headers['Authorization'], isNotEmpty);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'eventId': 'event-4',
          'ticketTypeId': 'type-2',
          'quantity': 1,
        });
        expect(body.containsKey('amount'), isFalse);
        expect(body.containsKey('total'), isFalse);
        return http.Response(
          jsonEncode({
            'data': {'id': 'order-10', 'total': 17500, 'status': 'pending'},
          }),
          201,
        );
      });
      final apiClient = ApiClient(
        baseUrl: 'https://tickets.example',
        client: client,
      )..tokenProvider = () async => 'access-token';
      final service = ApiPaymentService(apiClient: apiClient);

      final response = await service.createOrder(
        eventId: 'event-4',
        ticketTypeId: 'type-2',
        quantity: 1,
        idempotencyKey: 'retry-key-1',
      );

      expect(response['id'], 'order-10');
      expect(response['total'], 17500);
    },
  );

  test(
    'payment start accepts HTTPS checkout variants and omits the amount',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/orders/order-10/payment');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'airtelMoney');
        expect(body.containsKey('amount'), isFalse);
        expect(body.containsKey('total'), isFalse);
        return http.Response(
          jsonEncode({
            'data': {
              'payment_url': 'https://checkout.example/session/abc',
              'tx_ref': 'transaction-20',
              'amount': 17500,
              'currency': 'MWK',
            },
          }),
          200,
        );
      });
      final service = ApiPaymentService(
        apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client)
          ..tokenProvider = () async => 'access-token',
      );

      final session = await service.initiateOrderPayment(
        orderId: 'order-10',
        method: PaymentMethod.airtelMoney,
        phone: '0888123456',
      );

      expect(session.checkoutUrl, 'https://checkout.example/session/abc');
      expect(session.txRef, 'transaction-20');
      expect(session.amount, 17500);
    },
  );

  test('rejects a non-HTTPS checkout URL', () async {
    final service = ApiPaymentService(
      apiClient: ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'checkoutUrl': 'http://insecure.example/pay'}),
            200,
          ),
        ),
      )..tokenProvider = () async => 'access-token',
    );

    await expectLater(
      service.initiateOrderPayment(
        orderId: 'order-10',
        method: PaymentMethod.card,
        phone: '',
      ),
      throwsA(isA<PaymentException>()),
    );
  });

  test('parses server tickets while marking their source', () {
    final ticket = Ticket.fromServer({
      'id': 42,
      'userId': 'customer-7',
      'event': {'title': 'Festival', 'date': '2027-01-01'},
      'ticket_type': {'name': 'VIP', 'price': '17500'},
      'status': 'Issued',
      'payment_status': 'Paid',
      'qr_code': {'content': 'signed-ticket-payload'},
    }, authenticatedUserId: 'customer-7');

    expect(ticket.id, '42');
    expect(ticket.eventName, 'Festival');
    expect(ticket.ticketType, 'VIP');
    expect(ticket.price, 17500);
    expect(ticket.qrPayload, 'signed-ticket-payload');
    expect(ticket.source, 'server');
    expect(Ticket.fromJson(ticket.toJson()).source, 'server');
  });

  test(
    'real payment flow persists only server-issued tickets offline',
    () async {
      final requestBodies = <String, Map<String, dynamic>>{};
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == ApiEndpoints.orders) {
          requestBodies['order'] =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {'id': 'order-10', 'total': 17500, 'status': 'pending'},
            }),
            201,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/orders/order-10/payment') {
          requestBodies['payment'] =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'checkoutUrl': 'https://checkout.example/session/10',
                'txRef': 'tx-10',
              },
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/orders/order-10') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'order-10',
                'status': 'paid',
                'tickets': [
                  {
                    'id': 'ticket-10',
                    'userId': 'U-001',
                    'eventName': 'Festival',
                    'date': '2027-01-01',
                    'venue': 'Lilongwe',
                    'ticketType': 'VIP',
                    'status': 'Issued',
                    'paymentStatus': 'Paid',
                    'qrCode': 'signed-ticket-10',
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      final apiClient = ApiClient(
        baseUrl: 'https://tickets.example',
        client: client,
      )..tokenProvider = () async => 'access-token';
      final storage = TicketStorage(databasePath: ':memory:');
      final auth = AuthController(FakeAuthService());
      auth.setAuthenticatedUser(
        const AppUser(
          id: 'U-001',
          name: 'Demo User',
          email: 'demo@ticketmaster.mw',
        ),
      );
      final tickets = TicketsController(storage: storage, auth: auth);
      final service = ApiPaymentService(apiClient: apiClient);
      final controller = PaymentController(
        paymentService: service,
        orderRepository: OrderRepository(ticketStorage: storage),
        ticketsController: tickets,
        auth: auth,
      );
      const event = Event(
        id: 'event-4',
        title: 'Festival',
        date: '2027-01-01',
        time: '18:00',
        venue: 'Lilongwe',
        price: 90000,
        imagePath: '',
        category: 'Music',
      );

      await controller.begin(
        event: event,
        items: const [
          OrderItem(
            ticketTypeId: 'type-2',
            ticketTypeName: 'VIP',
            unitPrice: 90000,
            quantity: 1,
          ),
        ],
        total: 90000,
        method: PaymentMethod.card,
        phone: '',
      );

      expect(controller.order?.total, 17500);
      expect(requestBodies['order'], {
        'eventId': 'event-4',
        'ticketTypeId': 'type-2',
        'quantity': 1,
      });
      expect(requestBodies['payment']?.containsKey('amount'), isFalse);
      expect(await controller.finish(event, PaymentOutcome.success), isTrue);
      expect(controller.purchasedTickets.single.id, 'ticket-10');
      expect(controller.purchasedTickets.single.source, 'server');
      expect(
        (await storage.getSavedTickets(userId: 'U-001')).single.qrPayload,
        'signed-ticket-10',
      );

      controller.dispose();
      tickets.dispose();
      auth.dispose();
      await storage.close();
    },
  );
}
