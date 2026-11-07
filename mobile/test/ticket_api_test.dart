import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/tickets/data/ticket_api.dart';

void main() {
  test('loads issued tickets with the authenticated customer token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/tickets/my');
      expect(request.headers['Authorization'], 'Bearer customer-token');
      return http.Response(
        jsonEncode({
          'data': {
            'tickets': [
              {
                'id': 'ticket-1',
                'user_id': 'customer-1',
                'status': 'issued',
                'payment_status': 'paid',
                'event': {
                  'title': 'Festival',
                  'date': '2027-01-01',
                  'venue': 'Lilongwe',
                },
                'ticket_type': {'name': 'VIP', 'price': 25000},
                'qr_code': 'server-signed-ticket-qr',
              },
              {
                'id': 'pending-ticket',
                'status': 'pending',
                'payment_status': 'pending',
              },
            ],
          },
        }),
        200,
      );
    });
    final api = TicketApi(
      apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client),
      tokenProvider: () async => 'customer-token',
    );

    final tickets = await api.getMyTickets('customer-1');

    expect(tickets, hasLength(1));
    expect(tickets.single.eventName, 'Festival');
    expect(tickets.single.ticketType, 'VIP');
    expect(tickets.single.qrPayload, 'server-signed-ticket-qr');
    expect(tickets.single.userId, 'customer-1');
  });

  test("loads individual details and rejects another user's ticket", () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/tickets/ticket-2');
      return http.Response(
        jsonEncode({
          'data': {
            'ticket': {
              'id': 'ticket-2',
              'customer': {'id': 'customer-2'},
              'event_name': 'Concert',
              'status': 'valid',
              'qr_data': 'ticket-qr-data',
            },
          },
        }),
        200,
      );
    });
    final api = TicketApi(
      apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client),
      tokenProvider: () async => 'customer-token',
    );

    await expectLater(
      api.getTicketDetails('ticket-2', authenticatedUserId: 'customer-1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('validates a ticket using the backend validation endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/tickets/validate');
      expect(request.headers['Authorization'], 'Bearer customer-token');
      expect(jsonDecode(request.body), {'ticketId': 'ticket-9'});
      return http.Response(
        jsonEncode({
          'data': {
            'ticket': {
              'id': 'ticket-9',
              'user_id': 'customer-1',
              'status': 'validated',
              'event_name': 'Night Market',
              'payment_status': 'paid',
              'qr_code': 'validated-qr',
            },
          },
        }),
        200,
      );
    });

    final api = TicketApi(
      apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client),
      tokenProvider: () async => 'customer-token',
    );

    final ticket = await api.validateTicket(
      'ticket-9',
      authenticatedUserId: 'customer-1',
    );

    expect(ticket.id, 'ticket-9');
    expect(ticket.userId, 'customer-1');
    expect(ticket.qrPayload, 'validated-qr');
  });

  test('cancels a ticket using the backend cancellation endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/tickets/ticket-7/cancel');
      expect(request.headers['Authorization'], 'Bearer customer-token');
      return http.Response(
        jsonEncode({
          'data': {
            'ticket': {
              'id': 'ticket-7',
              'user_id': 'customer-1',
              'status': 'cancelled',
              'event_name': 'Farm Day',
              'payment_status': 'refunded',
              'qr_code': 'cancelled-qr',
            },
          },
        }),
        200,
      );
    });

    final api = TicketApi(
      apiClient: ApiClient(baseUrl: 'https://tickets.example', client: client),
      tokenProvider: () async => 'customer-token',
    );

    final ticket = await api.cancelTicket(
      'ticket-7',
      authenticatedUserId: 'customer-1',
    );

    expect(ticket.id, 'ticket-7');
    expect(ticket.userId, 'customer-1');
    expect(ticket.status, 'cancelled');
  });
}
