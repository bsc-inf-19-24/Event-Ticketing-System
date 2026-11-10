import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/events/event_api.dart';
import 'package:mobile/screens/home_screen.dart';

void main() {
  testWidgets('Home displays server events and no fake fallback', (
    WidgetTester tester,
  ) async {
    final eventApi = EventApi(
      client: ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/events');
          return http.Response(
            '[{"id":1,"name":"ZaMusic Festival","status":"AVAILABLE"}]',
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(onViewTickets: _onViewTickets, eventApi: eventApi),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZaMusic Festival'), findsOneWidget);
    expect(find.text('Blantyre Football Cup'), findsNothing);
  });

  testWidgets('Home shows no available events when server list is empty', (
    WidgetTester tester,
  ) async {
    final eventApi = EventApi(
      client: ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('[]', 200)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(onViewTickets: _onViewTickets, eventApi: eventApi),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No available events'), findsOneWidget);
    expect(find.text('ZaMusic Festival'), findsNothing);
  });
}

void _onViewTickets() {}
