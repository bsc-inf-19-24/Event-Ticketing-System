import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/events/event_api.dart';
import 'package:mobile/screens/home_screen.dart';

void main() {
  testWidgets(
    'Home excludes cancelled events even if availability says available',
    (WidgetTester tester) async {
      final eventApi = EventApi(
        client: ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient((request) async {
            if (request.url.path == '/api/events') {
              return http.Response(
                '[{"id":1,"name":"Cancelled show","status":"CANCELLED","availability":"AVAILABLE"},'
                '{"id":2,"name":"Live show","status":"PUBLISHED"}]',
                200,
              );
            }
            return http.Response('[]', 200);
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(onViewTickets: _onViewTickets, eventApi: eventApi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancelled show'), findsNothing);
      expect(find.text('Live show'), findsOneWidget);
    },
  );

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

  testWidgets('pulling down refreshes the Home event feed', (
    WidgetTester tester,
  ) async {
    var requestCount = 0;
    final eventApi = EventApi(
      client: ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/events') {
            requestCount++;
            return http.Response(
              '[{"id":1,"name":"Sports event $requestCount","category":"Sports","status":"AVAILABLE"}]',
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(onViewTickets: _onViewTickets, eventApi: eventApi),
      ),
    );
    await tester.pumpAndSettle();
    expect(requestCount, 1);
    expect(find.text('Sports event 1'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('Sports event 2'), findsOneWidget);
  });
}

void _onViewTickets() {}
