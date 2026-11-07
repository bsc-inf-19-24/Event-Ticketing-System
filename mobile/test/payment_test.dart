import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/orders/models/order.dart';
import 'package:mobile/features/orders/order_rules.dart';
import 'package:mobile/features/orders/services/order_repository.dart';
import 'package:mobile/features/payment/logic/payment_controller.dart';
import 'package:mobile/features/payment/logic/payment_verifier.dart';
import 'package:mobile/features/payment/models/payment_models.dart';
import 'package:mobile/features/payment/services/fake_payment_service.dart';
import 'package:mobile/features/payment/services/payment_service.dart';
import 'package:mobile/features/tickets/logic/tickets_controller.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FakePaymentService', () {
    test(
      'parses PayChangu-shaped checkout and verification responses',
      () async {
        final service = FakePaymentService(random: Random(1));
        final session = await service.initiateCheckout(_request());

        expect(session.txRef, 'TM-test-1');
        expect(session.checkoutUrl, contains('checkout.paychangu.com'));
        expect(session.currency, 'MWK');
        expect(session.amount, 100);
        expect(session.mode, 'test');
        expect(session.status, 'pending');

        final verification = await service.verifyPayment(session.txRef);
        expect(verification.txRef, session.txRef);
        expect(verification.status, 'pending');
        expect(verification.currency, 'MWK');
        expect(verification.amount, 100);
        expect(verification.mode, 'test');
        expect(verification.type, 'API Payment (Checkout)');
      },
    );

    test(
      'returns mobile-money operators and parses a charge response',
      () async {
        final service = FakePaymentService(random: Random(9));
        final operators = await service.getMobileMoneyOperators();
        expect(operators.map((operator) => operator.name), [
          'Airtel Money',
          'TNM Mpamba',
        ]);

        final charge = await service.chargeMobileMoney(
          operatorRefId: operators.first.refId,
          mobile: '0888123456',
          amount: 125,
          chargeId: 'TM-charge-1',
        );
        expect(charge.chargeId, 'TM-charge-1');
        expect(charge.refId, operators.first.refId);
        expect(charge.mobile, '0888123456');
        expect(charge.amount, 125);
        expect(charge.currency, 'MWK');
        expect(charge.status, 'pending');
      },
    );

    test(
      'checkout stays pending until completion and reflects outcomes',
      () async {
        final service = FakePaymentService(random: Random(2));
        await service.initiateCheckout(_request());
        expect((await service.verifyPayment('TM-test-1')).status, 'pending');

        service.completePayment('TM-test-1', PaymentOutcome.success);
        expect((await service.verifyPayment('TM-test-1')).status, 'success');

        final second = FakePaymentService(random: Random(3));
        await second.initiateCheckout(_request());
        second.completePayment('TM-test-1', PaymentOutcome.failed);
        expect((await second.verifyPayment('TM-test-1')).status, 'failed');
      },
    );

    test('rejects duplicate transaction references', () async {
      final service = FakePaymentService(random: Random(4));
      await service.initiateCheckout(_request());
      await expectLater(
        service.initiateCheckout(_request()),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('payment verification', () {
    const valid = PaymentVerification(
      txRef: 'expected',
      status: 'success',
      currency: 'MWK',
      amount: 100,
      mode: 'test',
      type: 'API Payment (Checkout)',
      attempts: 1,
    );

    test('accepts a correct payment', () {
      expect(
        isPaymentVerified(
          valid,
          expectedTxRef: 'expected',
          expectedAmount: 100,
        ),
        isTrue,
      );
    });

    test('rejects wrong tx_ref, currency, amount, and status', () {
      bool verify(PaymentVerification value) => isPaymentVerified(
        value,
        expectedTxRef: 'expected',
        expectedAmount: 100,
      );
      expect(verify(_verification(txRef: 'wrong')), isFalse);
      expect(verify(_verification(currency: 'USD')), isFalse);
      expect(verify(_verification(amount: 99)), isFalse);
      expect(verify(_verification(status: 'pending')), isFalse);
    });
  });

  test(
    'paid orders create unique tickets once; failed payments create none',
    () async {
      final auth = AuthController(FakeAuthService());
      await auth.logIn('demo@ticketmaster.mw', 'demo1234');
      final storage = _MemoryTicketStorage();
      final tickets = TicketsController(storage: storage, auth: auth);
      await tickets.load();
      final repository = OrderRepository(
        random: Random(5),
        ticketStorage: storage,
      );
      final order = _order();
      await repository.saveOrder(order);

      final duplicateAttempts = await Future.wait([
        repository.completePaidOrder(
          order: order,
          event: _event(),
          ticketsController: tickets,
          buyerName: 'Demo User',
          buyerEmail: 'demo@ticketmaster.mw',
        ),
        repository.completePaidOrder(
          order: order,
          event: _event(),
          ticketsController: tickets,
          buyerName: 'Demo User',
          buyerEmail: 'demo@ticketmaster.mw',
        ),
      ]);
      final created = duplicateAttempts.expand((attempt) => attempt).toList();
      expect(created, hasLength(1));
      expect(
        duplicateAttempts.where((attempt) => attempt.isEmpty),
        hasLength(1),
      );
      expect(created.map((ticket) => ticket.id).toSet(), hasLength(1));
      expect(created.map((ticket) => ticket.qrData).toSet(), hasLength(1));
      expect(created.every((ticket) => ticket.userId == 'U-001'), isTrue);
      expect(created.single.paymentId, order.txRef);
      expect(created.single.orderId, order.id);
      expect(created.single.buyerName, 'Demo User');
      expect(created.single.buyerEmail, 'demo@ticketmaster.mw');
      expect(
        await repository.completePaidOrder(
          order: order,
          event: _event(),
          ticketsController: tickets,
          buyerName: 'Demo User',
          buyerEmail: 'demo@ticketmaster.mw',
        ),
        isEmpty,
      );

      final failingService = FakePaymentService(random: Random(6));
      final failedRepository = OrderRepository(random: Random(7));
      final failedTickets = TicketsController(
        storage: _MemoryTicketStorage(),
        auth: auth,
      );
      await failedTickets.load();
      final controller = PaymentController(
        paymentService: failingService,
        orderRepository: failedRepository,
        ticketsController: failedTickets,
        auth: auth,
        random: Random(8),
      );
      await controller.begin(
        event: _event(),
        items: order.items,
        total: order.total,
        method: PaymentMethod.card,
        phone: '',
      );
      expect(await controller.finish(_event(), PaymentOutcome.failed), isFalse);
      final failedOrders = await failedRepository.getOrdersForUser('U-001');
      expect(
        failedOrders
            .singleWhere((saved) => saved.id == controller.order!.id)
            .status,
        'failed',
      );
      expect(failedTickets.tickets, isEmpty);

      controller.dispose();
      failedTickets.dispose();
      tickets.dispose();
      auth.dispose();
    },
  );

  test('PaymentController rejects multiple tickets or ticket types', () async {
    final auth = AuthController(FakeAuthService());
    await auth.logIn('demo@ticketmaster.mw', 'demo1234');
    final controller = PaymentController(
      paymentService: FakePaymentService(random: Random(10)),
      orderRepository: OrderRepository(random: Random(11)),
      ticketsController: TicketsController(
        storage: _MemoryTicketStorage(),
        auth: auth,
      ),
      auth: auth,
      random: Random(12),
    );

    await expectLater(
      controller.begin(
        event: _event(),
        items: const [
          OrderItem(ticketTypeName: 'Standard', unitPrice: 50, quantity: 2),
        ],
        total: 100,
        method: PaymentMethod.card,
        phone: '',
      ),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      controller.begin(
        event: _event(),
        items: const [
          OrderItem(ticketTypeName: 'Standard', unitPrice: 50, quantity: 1),
          OrderItem(ticketTypeName: 'VIP', unitPrice: 100, quantity: 1),
        ],
        total: 150,
        method: PaymentMethod.card,
        phone: '',
      ),
      throwsA(isA<PaymentException>()),
    );
    expect(controller.order, isNull);
    controller.dispose();
    auth.dispose();
  });

  test(
    'a successful payment creates one ticket with buyer and payment details',
    () async {
      final auth = AuthController(FakeAuthService());
      await auth.logIn('demo@ticketmaster.mw', 'demo1234');
      final ticketStorage = _MemoryTicketStorage();
      final tickets = TicketsController(storage: ticketStorage, auth: auth);
      await tickets.load();
      final controller = PaymentController(
        paymentService: FakePaymentService(random: Random(13)),
        orderRepository: OrderRepository(random: Random(14)),
        ticketsController: tickets,
        auth: auth,
        random: Random(15),
      );
      await controller.begin(
        event: _event(),
        items: const [
          OrderItem(
            ticketTypeName: 'Standard',
            unitPrice: 50,
            quantity: maxTicketsPerOrder,
          ),
        ],
        total: 50,
        method: PaymentMethod.card,
        phone: '',
      );

      expect(await controller.finish(_event(), PaymentOutcome.success), isTrue);
      expect(controller.purchasedTickets, hasLength(1));
      final ticket = controller.purchasedTickets.single;
      expect(ticket.paymentId, controller.order!.txRef);
      expect(ticket.orderId, controller.order!.id);
      expect(ticket.buyerName, 'Demo User');
      expect(ticket.buyerEmail, 'demo@ticketmaster.mw');

      controller.dispose();
      tickets.dispose();
      auth.dispose();
    },
  );

  test('Ticket JSON supports old data and round-trips the receipt fields', () {
    final oldTicket = Ticket.fromJson({
      'id': 'TM-000001',
      'eventName': 'Event',
      'date': '10 Nov 2026',
      'venue': 'Lilongwe',
      'status': 'Confirmed',
      'qrData': 'TM|ticket',
    });
    expect(oldTicket.paymentId, isEmpty);
    expect(oldTicket.orderId, isEmpty);
    expect(oldTicket.buyerName, isEmpty);
    expect(oldTicket.buyerEmail, isEmpty);

    final ticket = Ticket(
      id: 'TM-000002',
      eventName: 'Event',
      date: '10 Nov 2026',
      venue: 'Lilongwe',
      status: 'Confirmed',
      qrData: 'TM|receipt',
      paymentId: 'TM-payment',
      orderId: 'ORD-payment',
      buyerName: 'Demo User',
      buyerEmail: 'demo@ticketmaster.mw',
    );
    final restored = Ticket.fromJson(ticket.toJson());
    expect(restored.paymentId, ticket.paymentId);
    expect(restored.orderId, ticket.orderId);
    expect(restored.buyerName, ticket.buyerName);
    expect(restored.buyerEmail, ticket.buyerEmail);
  });

  test(
    'TicketsController clears on logout and filters tickets by user',
    () async {
      final auth = AuthController(FakeAuthService());
      final storage = _MemoryTicketStorage();
      await storage.saveTickets([
        _ticket(id: 'TM-000001', userId: 'U-001'),
        _ticket(id: 'TM-000002', userId: 'U-002'),
      ]);
      final controller = TicketsController(storage: storage, auth: auth);

      await auth.logIn('demo@ticketmaster.mw', 'demo1234');
      await controller.load();
      expect(controller.tickets.map((ticket) => ticket.userId), ['U-001']);

      auth.logOut();
      expect(controller.tickets, isEmpty);

      await auth.logIn('test.customer@example.com', 'SecurePassword123!');
      await controller.load();
      expect(controller.tickets.map((ticket) => ticket.userId), ['U-002']);

      controller.dispose();
      auth.dispose();
    },
  );
}

PaymentRequest _request() => const PaymentRequest(
  amount: 100,
  email: 'customer@example.com',
  firstName: 'Test',
  lastName: 'Customer',
  txRef: 'TM-test-1',
);

PaymentVerification _verification({
  String txRef = 'expected',
  String status = 'success',
  String currency = 'MWK',
  int amount = 100,
}) => PaymentVerification(
  txRef: txRef,
  status: status,
  currency: currency,
  amount: amount,
  mode: 'test',
  type: 'API Payment (Checkout)',
  attempts: 1,
);

Order _order({String id = 'ORD-test', String txRef = 'TM-test'}) => Order(
  id: id,
  userId: 'U-001',
  eventTitle: 'Sample event',
  eventVenue: 'Lilongwe',
  eventDate: '10 Nov 2026',
  items: const [
    OrderItem(
      ticketTypeName: 'Standard',
      unitPrice: 50,
      quantity: maxTicketsPerOrder,
    ),
  ],
  total: 50,
  status: 'pending',
  txRef: txRef,
  paymentMethod: 'card',
  createdAt: DateTime(2026, 11, 10),
);

Event _event() => const Event(
  title: 'Sample event',
  date: '10 Nov 2026',
  time: '18:00',
  venue: 'Lilongwe',
  price: 50,
  imagePath: 'assets/images/show.jpg',
  category: 'Concerts',
);

Ticket _ticket({required String id, required String userId}) => Ticket(
  id: id,
  eventName: 'Event',
  date: '10 Nov 2026',
  venue: 'Lilongwe',
  status: 'Confirmed',
  qrData: 'TM|$id',
  userId: userId,
);

class _MemoryTicketStorage extends TicketStorage {
  final List<Ticket> _tickets = [];

  @override
  Future<List<Ticket>> getSavedTickets({String? userId}) async => userId == null
      ? List.of(_tickets)
      : _tickets.where((ticket) => ticket.userId == userId).toList();

  @override
  Future<void> saveTickets(List<Ticket> tickets) async {
    final ids = _tickets.map((ticket) => ticket.id).toSet();
    for (final ticket in tickets) {
      if (ids.add(ticket.id)) _tickets.add(ticket);
    }
  }
}
