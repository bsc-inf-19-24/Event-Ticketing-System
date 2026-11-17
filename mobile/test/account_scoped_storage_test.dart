import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/storage/pending_checkout_store.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/features/tickets/data/ticket_api.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_repository.dart';
import 'package:mobile/services/ticket_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'ticket scopes isolate users and preserve the same user offline',
    () async {
      final storage = TicketStorage(databasePath: ':memory:');
      await storage.saveTicket(_ticket('srv-1', 'user-a'));
      final auth = AuthController(FakeAuthService());
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-b', name: 'B', email: 'b@example.com'),
      );
      expect(await storage.getSavedTickets(userId: auth.stableUserId), isEmpty);
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-a', name: 'A', email: 'a@example.com'),
      );
      final cached = await storage.getSavedTickets(userId: auth.stableUserId);
      expect(cached.map((ticket) => ticket.id), ['srv-1']);
      auth.logOut();
      expect(await storage.getSavedTickets(), isEmpty);
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-a', name: 'A', email: 'a@example.com'),
      );
      expect(
        (await storage.getSavedTickets(userId: auth.stableUserId)).single.id,
        'srv-1',
      );
      auth.dispose();
      await storage.close();
    },
  );

  test(
    'one-time cleanup removes legacy ticket records and leaves valid records',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved_demo_tickets': jsonEncode([
          {'id': 'TKT-001'},
        ]),
      });
      final storage = TicketStorage(databasePath: ':memory:');
      await storage.migrateLegacyRecords();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_demo_tickets'), isNull);
      expect(prefs.getBool('ticket_legacy_cleanup_v2'), isTrue);

      await storage.saveTickets([
        _ticket('TM-366162', 'user-a', source: 'fake'),
        _ticket('server-2', 'user-a'),
      ]);
      await prefs.remove('ticket_legacy_cleanup_v2');
      await storage.migrateLegacyRecords();
      expect(
        (await storage.getSavedTickets(userId: 'user-a')).map((t) => t.id),
        ['server-2'],
      );
      await storage.close();
    },
  );

  test(
    'duplicate server ticket IDs are returned once and saved once',
    () async {
      final value = {
        'id': 'ticket-1',
        'userId': 'user-a',
        'eventName': 'Live event',
        'status': 'Issued',
        'qrCode': 'signed-code',
      };
      final apiClient = ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': [value, value],
            }),
            200,
          ),
        ),
      );
      final api = TicketApi(
        apiClient: apiClient,
        tokenProvider: () async => 'test-token',
      );
      final storage = TicketStorage(databasePath: ':memory:');
      final result = await TicketRepository(
        storage: storage,
        api: api,
      ).load(userId: 'user-a', hasConnection: true);
      expect(result.tickets.map((ticket) => ticket.id), ['ticket-1']);
      expect(await storage.getSavedTickets(userId: 'user-a'), hasLength(1));
      await storage.close();
    },
  );

  test(
    'pending checkout data is private to its user and retains its timestamp',
    () async {
      final auth = authController;
      final store = PendingCheckoutStore();
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-a', name: 'A', email: 'a@example.com'),
      );
      await store.save('order-a', now: DateTime(2026, 1, 1));
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-b', name: 'B', email: 'b@example.com'),
      );
      expect(await store.read(), isNull);
      auth.setAuthenticatedUser(
        const AppUser(id: 'user-a', name: 'A', email: 'a@example.com'),
      );
      final pending = await store.read();
      expect(pending?.orderId, 'order-a');
      expect(pending?.createdAt, DateTime(2026, 1, 1));
      await store.clear();
      auth.logOut();
    },
  );
}

Ticket _ticket(String id, String userId, {String source = 'server'}) => Ticket(
  id: id,
  eventName: 'Event',
  date: '2026-12-01T18:30:00',
  venue: 'Hall',
  status: 'Issued',
  qrData: 'qr-$id',
  userId: userId,
  source: source,
);
