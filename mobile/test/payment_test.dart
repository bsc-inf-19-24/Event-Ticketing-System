import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/orders/models/order.dart';
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
      final storage = TicketStorage();
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
        ),
        repository.completePaidOrder(
          order: order,
          event: _event(),
          ticketsController: tickets,
        ),
      ]);
      final created = duplicateAttempts.expand((attempt) => attempt).toList();
      expect(created, hasLength(2));
      expect(
        duplicateAttempts.where((attempt) => attempt.isEmpty),
        hasLength(1),
      );
      expect(created.map((ticket) => ticket.id).toSet(), hasLength(2));
      expect(created.map((ticket) => ticket.qrData).toSet(), hasLength(2));
      expect(created.every((ticket) => ticket.userId == 'U-001'), isTrue);
      expect(
        await repository.completePaidOrder(
          order: order,
          event: _event(),
          ticketsController: tickets,
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

  test(
    'TicketsController clears on logout and filters tickets by user',
    () async {
      final auth = AuthController(FakeAuthService());
      final storage = TicketStorage();
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
    OrderItem(ticketTypeName: 'Standard', unitPrice: 50, quantity: 2),
  ],
  total: 100,
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
