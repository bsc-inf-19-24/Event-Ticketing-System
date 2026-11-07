import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/tickets/data/ticket_api.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_repository.dart';
import 'package:mobile/services/ticket_storage.dart';

void main() {
  test('retrieves, synchronizes, opens, then reads tickets offline', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer integration-token');
      if (request.url.path == '/api/tickets/my') {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'issued-1',
                'userId': 'customer-1',
                'eventName': 'Paid festival',
                'date': '2027-01-01',
                'venue': 'Lilongwe',
                'ticketType': 'VIP',
                'status': 'Issued',
                'paymentStatus': 'Paid',
                'qrCode': 'backend-qr-payload',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/tickets/issued-1') {
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'issued-1',
              'userId': 'customer-1',
              'eventName': 'Paid festival',
              'date': '2027-01-01',
              'venue': 'Updated venue',
              'ticketType': 'VIP',
              'status': 'Issued',
              'paymentStatus': 'Paid',
              'qrCode': 'backend-qr-payload',
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final storage = TicketStorage(databasePath: ':memory:');
    final repository = TicketRepository(
      storage: storage,
      api: TicketApi(
        apiClient: ApiClient(
          baseUrl: 'https://tickets.example',
          client: client,
        ),
        tokenProvider: () async => 'integration-token',
      ),
    );

    final online = await repository.load(
      userId: 'customer-1',
      hasConnection: true,
    );
    expect(online.tickets, hasLength(1));
    expect(online.tickets.single.paymentStatus, 'Paid');

    final details = await repository.getTicketDetails(
      ticketId: 'issued-1',
      userId: 'customer-1',
      hasConnection: true,
    );
    expect(details.venue, 'Updated venue');
    expect(details.qrPayload, 'backend-qr-payload');

    final offline = await repository.load(
      userId: 'customer-1',
      hasConnection: false,
    );
    expect(offline.isOffline, isTrue);
    expect(offline.tickets.single.venue, 'Updated venue');
    expect(offline.tickets.single.qrPayload, 'backend-qr-payload');
    expect(await storage.getSavedTickets(userId: 'another-customer'), isEmpty);

    final duplicate = details.copyWith(venue: 'Latest venue');
    await storage.synchronizeUserTickets('customer-1', [details, duplicate]);
    final synced = await storage.getSavedTickets(userId: 'customer-1');
    expect(synced, hasLength(1));
    expect(synced.single.venue, 'Latest venue');
  });

  test('refuses to store backend tickets owned by another user', () async {
    final storage = TicketStorage(databasePath: ':memory:');
    final foreignTicket = Ticket(
      id: 'foreign-1',
      userId: 'user-b',
      eventName: 'Private event',
      date: '',
      venue: '',
      status: 'Issued',
      qrData: 'private-qr',
    );
    await expectLater(
      storage.synchronizeUserTickets('user-a', [foreignTicket]),
      throwsA(isA<StateError>()),
    );
    expect(await storage.getSavedTickets(userId: 'user-a'), isEmpty);
  });
}
