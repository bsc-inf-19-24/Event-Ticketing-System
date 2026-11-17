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
          'items': [
            {'ticketTypeId': 'type-2', 'quantity': 1},
          ],
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
        items: const [
          OrderItem(
            ticketTypeId: 'type-2',
            ticketTypeName: 'VIP',
            unitPrice: 17500,
            quantity: 1,
          ),
        ],
        idempotencyKey: 'retry-key-1',
      );

      expect(response['id'], 'order-10');
      expect(response['total'], 17500);
    },
  );

  test(
    'payment start sends order amount and accepts HTTPS checkout variants',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, ApiEndpoints.paymentCheckout);
        expect(request.headers['Authorization'], 'Bearer access-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {'orderId': 'order-10', 'amount': 17500});
        expect(body.containsKey('total'), isFalse);
        return http.Response(
          jsonEncode({
            'data': {
              'checkout_url': 'https://checkout.example/session/abc',
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
        amount: 17500,
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
        amount: 17500,
        method: PaymentMethod.card,
        phone: '',
      ),
      throwsA(isA<PaymentException>()),
    );
  });

  test(
    'preserves the backend checkout error message and status code',
    () async {
      final service = ApiPaymentService(
        apiClient: ApiClient(
          baseUrl: 'https://tickets.example',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'data': {'message': 'PayChangu is not configured'},
              }),
              422,
            ),
          ),
        )..tokenProvider = () async => 'access-token',
      );

      await expectLater(
        service.initiateOrderPayment(
          orderId: 'order-10',
          amount: 17500,
          method: PaymentMethod.card,
          phone: '',
        ),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.message,
                'message',
                'PayChangu is not configured',
              )
              .having((error) => error.statusCode, 'statusCode', 422),
        ),
      );
    },
  );

  test(
    'mock payment sends the order, amount, and succeed flag with auth',
    () async {
      final service = ApiPaymentService(
        apiClient: ApiClient(
          baseUrl: 'https://tickets.example',
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, ApiEndpoints.payments);
            expect(request.headers['Authorization'], 'Bearer access-token');
            expect(jsonDecode(request.body), {
              'orderId': 'order-10',
              'amount': 17500,
              'succeed': true,
            });
            return http.Response(jsonEncode({'status': 'paid'}), 200);
          }),
        )..tokenProvider = () async => 'access-token',
      );

      final result = await service.createMockPayment(
        orderId: 'order-10',
        amount: 17500,
      );
      expect(result['status'], 'paid');
    },
  );

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
            request.url.path == ApiEndpoints.paymentCheckout) {
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
        if (request.method == 'POST' &&
            request.url.path == ApiEndpoints.paymentVerify) {
          return http.Response(
            jsonEncode({
              'data': {
                'order': {
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
                'paymentStatus': 'paid',
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
        'items': [
          {'ticketTypeId': 'type-2', 'quantity': 1},
        ],
      });
      expect(requestBodies['payment'], {
        'orderId': 'order-10',
        'amount': 17500,
      });
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

  test('mock API payment verifies and refreshes issued tickets', () async {
    final calls = <String, Map<String, dynamic>>{};
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer access-token');
      if (request.url.path == ApiEndpoints.orders) {
        return http.Response(
          jsonEncode({
            'data': {'id': 'order-mock', 'total': 17500, 'status': 'pending'},
          }),
          201,
        );
      }
      if (request.url.path == ApiEndpoints.payments) {
        calls['mock'] = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'paid'}), 200);
      }
      if (request.url.path == ApiEndpoints.paymentVerify) {
        return http.Response(
          jsonEncode({
            'order': {
              'id': 'order-mock',
              'status': 'paid',
              'tickets': [
                {
                  'id': 'ticket-mock',
                  'userId': 'U-001',
                  'status': 'Issued',
                  'paymentStatus': 'Paid',
                  'qrCode': 'mock-ticket-qr',
                },
              ],
            },
            'paymentStatus': 'paid',
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
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
    final service = ApiPaymentService(
      apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client)
        ..tokenProvider = () async => 'access-token',
    );
    final controller = PaymentController(
      paymentService: service,
      orderRepository: OrderRepository(ticketStorage: storage),
      ticketsController: tickets,
      auth: auth,
      useMockPayment: true,
    );
    const event = Event(
      id: 'event-4',
      title: 'Festival',
      date: '2027-01-01',
      time: '18:00',
      venue: 'Lilongwe',
      price: 17500,
      imagePath: '',
      category: 'Music',
    );

    await controller.begin(
      event: event,
      items: const [
        OrderItem(
          ticketTypeId: 'type-2',
          ticketTypeName: 'VIP',
          unitPrice: 17500,
          quantity: 1,
        ),
      ],
      total: 17500,
      method: PaymentMethod.card,
      phone: '',
    );

    expect(calls['mock'], {
      'orderId': 'order-mock',
      'amount': 17500,
      'succeed': true,
    });
    expect(controller.paymentState, 'paid');
    expect(controller.purchasedTickets.single.qrPayload, 'mock-ticket-qr');
    expect(
      (await storage.getSavedTickets(userId: 'U-001')).single.id,
      'ticket-mock',
    );

    controller.dispose();
    tickets.dispose();
    auth.dispose();
    await storage.close();
  });
}
