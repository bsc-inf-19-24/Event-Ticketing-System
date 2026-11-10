import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/screens/event_details_screen.dart';

void main() {
  testWidgets('published event with active inventory can be purchased', (
    WidgetTester tester,
  ) async {
    const event = Event(
      id: 'event-1',
      title: 'Published festival',
      date: '2027-01-01',
      time: '6:00 PM',
      venue: 'Lilongwe',
      price: 17500,
      imagePath: '',
      category: 'Music',
      status: 'PUBLISHED',
      ticketTypes: [
        TicketType(
          id: 'type-1',
          name: 'Standard',
          price: 17500,
          status: 'ACTIVE',
          remainingInventory: 4,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: EventDetailsScreen(event: event)),
    );

    final buyButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Buy Ticket'),
    );
    expect(buyButton.onPressed, isNotNull);
  });

  testWidgets('sold-out ticket types cannot be purchased', (
    WidgetTester tester,
  ) async {
    const event = Event(
      id: 'event-2',
      title: 'Sold out festival',
      date: '2027-01-01',
      time: '6:00 PM',
      venue: 'Lilongwe',
      price: 17500,
      imagePath: '',
      category: 'Music',
      status: 'PUBLISHED',
      ticketTypes: [
        TicketType(
          id: 'type-2',
          name: 'Standard',
          price: 17500,
          status: 'ACTIVE',
          remainingInventory: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: EventDetailsScreen(event: event)),
    );

    final unavailableButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Not available'),
    );
    expect(unavailableButton.onPressed, isNull);
  });
}
