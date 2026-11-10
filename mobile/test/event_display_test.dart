import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/events/event_api.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/screens/event_details_screen.dart';
import 'package:mobile/widgets/event_card.dart';

const afroFusionJson = <String, dynamic>{
  'id': 7,
  'title': 'AfroFusion Live 2026',
  'category': 'Concerts',
  'genre': null,
  'venue': 'Comesa Hall',
  'location': 'Blantyre',
  'startTime': '2026-11-21T18:00:00',
  'endTime': '2026-11-21T23:30:00',
  'status': 'PUBLISHED',
  'availability': 'AVAILABLE',
  'coverImagePath': '/uploads/events/8f3a1c2e.jpg',
  'minPrice': 15000,
  'capacity': 300,
  'remainingTickets': 300,
  'ticketTypes': [
    {
      'id': 11,
      'name': 'Standard',
      'price': 15000,
      'totalQuantity': 250,
      'remaining': 250,
    },
    {
      'id': 12,
      'name': 'VIP',
      'price': 30000,
      'totalQuantity': 50,
      'remaining': 50,
    },
  ],
};

void main() {
  group('event mapping and display formatting', () {
    test('maps the backend JSON without exposing raw date text', () async {
      final event = await _apiFor(
        (_) async => http.Response(jsonEncode(afroFusionJson), 200),
      ).details('7');
      expect(event.id, '7');
      expect(event.displayDate, 'Saturday, 21 November 2026');
      expect(event.displayStartTime, '6:00 PM');
      expect(event.timeRange, '6:00 PM - 11:30 PM');
      expect(event.place, 'Comesa Hall, Blantyre');
      expect(event.displayGenre, 'Music & Entertainment');
      expect(event.price, 15000);
      expect(event.statusLabel, 'Available');
      expect(event.ticketTypes.map((type) => type.id), ['11', '12']);
      expect(event.ticketTypes.map((type) => type.remainingInventory), [
        250,
        50,
      ]);
      expect(event.displayDate, isNot(contains('2026-11-21T')));
    });

    test('dateTime is a tolerant fallback when startTime is missing', () async {
      final json = Map<String, dynamic>.from(afroFusionJson)
        ..remove('startTime')
        ..['dateTime'] = '2026-12-05T15:00:00';
      final event = await _apiFor(
        (_) async => http.Response(jsonEncode(json), 200),
      ).details('7');
      expect(event.displayDate, 'Saturday, 5 December 2026');
      expect(event.displayStartTime, '3:00 PM');
    });

    test(
      'missing start hides date and time and location defaults safely',
      () async {
        final json = Map<String, dynamic>.from(afroFusionJson)
          ..remove('startTime')
          ..remove('dateTime')
          ..remove('location');
        final event = await _apiFor(
          (_) async => http.Response(jsonEncode(json), 200),
        ).details('7');
        expect(event.hasStart, isFalse);
        expect(event.displayDate, isEmpty);
        expect(event.timeRange, isEmpty);
        expect(event.place, 'Comesa Hall');
      },
    );

    test(
      'genre fallback maps agreed categories and preserves other labels',
      () {
        const cases = {
          'Concerts': 'Music & Entertainment',
          'Sports': 'Sports',
          'Workshop': 'Workshop',
          'Festival': 'Festival',
          'Other': 'Other',
          'Custom category': 'Custom category',
          '': '',
        };
        for (final entry in cases.entries) {
          final event = Event(
            title: 'Event',
            date: '',
            time: '',
            venue: '',
            price: 0,
            imagePath: '',
            category: entry.key,
          );
          expect(event.displayGenre, entry.value);
        }
      },
    );

    test('availability always maps to a display label', () {
      const cases = {
        'AVAILABLE': 'Available',
        'SOLD_OUT': 'Sold out',
        'ENDED': 'Ended',
        'CANCELLED': 'Cancelled',
      };
      for (final entry in cases.entries) {
        final event = Event(
          title: 'Event',
          date: '',
          time: '',
          venue: '',
          price: 0,
          imagePath: '',
          category: '',
          availability: entry.key,
        );
        expect(event.statusLabel, entry.value);
      }
    });

    test('no types and zero prices have safe price text', () {
      final event = Event(
        title: 'Event',
        date: '',
        time: '',
        venue: '',
        price: 0,
        imagePath: '',
        category: '',
      );
      expect(event.ticketTypes, isEmpty);
      expect(_cardPrice(event), 'Price: TBA');
      final free = Event(
        title: 'Free event',
        date: '',
        time: '',
        venue: '',
        price: 0,
        imagePath: '',
        category: '',
        ticketTypes: const [TicketType(name: 'Entry', price: 0)],
      );
      expect(_cardPrice(free), 'Price: Free');
    });
  });

  testWidgets('event card displays formatted agreed details', (tester) async {
    final event = await _apiFor(
      (_) async => http.Response(jsonEncode(afroFusionJson), 200),
    ).details('7');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventCard(event: event)),
      ),
    );
    expect(find.text('AfroFusion Live 2026'), findsOneWidget);
    expect(find.text('Saturday, 21 November 2026'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);
    expect(find.text('Comesa Hall, Blantyre'), findsOneWidget);
    expect(find.text('Price: MWK 15,000'), findsOneWidget);
    expect(find.textContaining('2026-11-21T'), findsNothing);
  });

  testWidgets('details screen displays AfroFusion types and server capacity', (
    tester,
  ) async {
    final event = await _apiFor(
      (_) async => http.Response(jsonEncode(afroFusionJson), 200),
    ).details('7');
    await tester.pumpWidget(
      MaterialApp(home: EventDetailsScreen(event: event)),
    );
    await tester.scrollUntilVisible(find.text('VIP Ticket'), 300);
    expect(find.text('AfroFusion Live 2026'), findsOneWidget);
    expect(find.text('Music & Entertainment'), findsOneWidget);
    expect(find.text('6:00 PM - 11:30 PM'), findsOneWidget);
    expect(find.text('Comesa Hall, Blantyre'), findsOneWidget);
    expect(find.text('Standard Ticket'), findsOneWidget);
    expect(find.text('VIP Ticket'), findsOneWidget);
    expect(find.text('Capacity: 300'), findsOneWidget);
    expect(find.text('Status: Available'), findsOneWidget);
    expect(find.textContaining('PUBLISHED'), findsNothing);
  });

  testWidgets('details without types show safe empty state and disabled buy', (
    tester,
  ) async {
    final json = Map<String, dynamic>.from(afroFusionJson)
      ..['ticketTypes'] = <dynamic>[];
    final event = await _apiFor(
      (_) async => http.Response(jsonEncode(json), 200),
    ).details('7');
    await tester.pumpWidget(
      MaterialApp(home: EventDetailsScreen(event: event)),
    );
    await tester.scrollUntilVisible(find.text('No tickets on sale yet'), 300);
    expect(find.text('No tickets on sale yet'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Buy Ticket'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('loading two event details in a row never mixes ticket types', (
    tester,
  ) async {
    final api = _apiFor((request) async {
      final id = request.url.pathSegments.last;
      final json = Map<String, dynamic>.from(afroFusionJson)
        ..['id'] = int.parse(id)
        ..['title'] = 'Event $id'
        ..['capacity'] = id == '7' ? 300 : 900
        ..['ticketTypes'] = [
          {
            'id': id == '7' ? 11 : 21,
            'name': id == '7' ? 'Standard' : 'Balcony',
            'price': id == '7' ? 15000 : 9000,
            'remaining': 5,
          },
        ];
      return http.Response(jsonEncode(json), 200);
    });
    final first = await api.details('7');
    await tester.pumpWidget(
      MaterialApp(home: EventDetailsScreen(event: first)),
    );
    await tester.scrollUntilVisible(find.text('Standard Ticket'), 300);
    expect(find.text('Standard Ticket'), findsOneWidget);
    expect(find.text('Balcony Ticket'), findsNothing);
    expect(find.text('Capacity: 300'), findsOneWidget);

    final second = await api.details('9');
    await tester.pumpWidget(
      MaterialApp(home: EventDetailsScreen(event: second)),
    );
    await tester.scrollUntilVisible(find.text('Balcony Ticket'), 300);
    expect(find.text('Balcony Ticket'), findsOneWidget);
    expect(find.text('Standard Ticket'), findsNothing);
    expect(find.text('Capacity: 900'), findsOneWidget);
  });
}

EventApi _apiFor(Future<http.Response> Function(http.Request) handler) =>
    EventApi(
      client: ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient(handler),
      ),
    );

String _cardPrice(Event event) => event.ticketTypes.isEmpty
    ? 'Price: TBA'
    : event.price == 0
    ? 'Price: Free'
    : 'Price: MWK ${event.price}';
