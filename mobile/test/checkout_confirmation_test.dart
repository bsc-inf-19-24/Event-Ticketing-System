import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/orders/models/order.dart';
import 'package:mobile/features/payment/models/payment_models.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/screens/checkout_screen.dart';

void main() {
  testWidgets('checkout confirms ticket selection without payment inputs', (
    tester,
  ) async {
    const event = Event(
      id: '7',
      title: 'AfroFusion Live 2026',
      date: 'Saturday, 21 November 2026',
      time: '6:00 PM',
      venue: 'Comesa Hall',
      location: 'Blantyre',
      price: 15000,
      imagePath: '',
      category: 'Concerts',
      availability: 'AVAILABLE',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: CheckoutScreen(
          event: event,
          items: [
            OrderItem(
              ticketTypeId: '11',
              ticketTypeName: 'Standard',
              unitPrice: 15000,
              quantity: 2,
            ),
          ],
          total: 30000,
        ),
      ),
    );

    expect(find.text('AfroFusion Live 2026'), findsOneWidget);
    expect(find.text('Standard Ticket × 2'), findsOneWidget);
    expect(find.text('MWK 30,000'), findsOneWidget);
    expect(
      find.text('You will enter your payment details securely on PayChangu.'),
      findsOneWidget,
    );
    expect(find.text('Proceed to payment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Mobile money phone number'), findsNothing);
    expect(find.text('Payment method'), findsNothing);
    expect(find.byType(RadioListTile<PaymentMethod>), findsNothing);
  });
}
