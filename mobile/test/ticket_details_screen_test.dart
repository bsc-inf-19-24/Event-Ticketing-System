import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/screens/ticket_details_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('shows only permitted ticket details alongside the QR code', (
    WidgetTester tester,
  ) async {
    final ticket = Ticket(
      id: 'hidden-ticket-id',
      eventName: 'Hidden event name',
      date: '2026-12-01',
      venue: 'Lilongwe',
      status: 'Issued',
      qrData: 'ticket-qr-payload',
      ticketType: 'Hidden ticket type',
      price: 1500,
      purchasedOn: '2026-11-20',
      userId: 'user-123',
      paymentId: 'hidden-payment-id',
      orderId: 'hidden-order-id',
      buyerName: 'Ticket Holder',
      buyerEmail: 'holder@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TicketDetailsScreen(
          ticket: ticket,
          onDownload: (_) async => true,
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Ticket Holder'), findsOneWidget);
    expect(find.text('holder@example.com'), findsOneWidget);
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('user-123'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('MWK 1,500'), findsOneWidget);
    expect(find.text('Venue'), findsOneWidget);
    expect(find.text('Lilongwe'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('2026-12-01'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Issued'), findsOneWidget);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Not used'), findsOneWidget);
    expect(find.text('Purchased: 2026-11-20'), findsOneWidget);

    expect(find.text('Hidden event name'), findsNothing);
    expect(find.text('Hidden ticket type'), findsNothing);
    expect(find.text('hidden-ticket-id'), findsNothing);
    expect(find.text('Payment ID'), findsNothing);
    expect(find.text('hidden-payment-id'), findsNothing);
    expect(find.text('Order ID'), findsNothing);
    expect(find.text('hidden-order-id'), findsNothing);
  });
}
