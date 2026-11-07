import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_repository.dart';
import 'package:mobile/services/ticket_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores tickets across database reopen and supports CRUD', () async {
    final databaseName =
        'ticket_storage_test_${DateTime.now().microsecondsSinceEpoch}.db';
    final ticket = Ticket(
      id: 'ticket-1',
      userId: 'local-user',
      eventName: 'Local concert',
      date: '5 Dec 2026, 3:00 PM',
      venue: 'City Hall',
      status: 'Confirmed',
      qrData: 'qr-ticket-1',
      price: 2500,
    );
    final storage = TicketStorage(databaseName: databaseName);

    await storage.saveTicket(ticket);
    final stored = await storage.getTicket(ticket.id);

    expect(stored, isNotNull);
    expect(stored!.eventName, ticket.eventName);
    expect(stored.downloadedAt, isNotEmpty);

    await storage.saveTicket(
      Ticket(
        id: ticket.id,
        userId: ticket.userId,
        eventName: 'Duplicate',
        date: ticket.date,
        venue: ticket.venue,
        status: ticket.status,
        qrData: ticket.qrData,
        price: ticket.price,
      ),
    );
    expect((await storage.getSavedTickets()), hasLength(1));
    expect((await storage.getTicket(ticket.id))!.eventName, ticket.eventName);

    await storage.close();
    final reopenedStorage = TicketStorage(databaseName: databaseName);
    expect((await reopenedStorage.getTicket(ticket.id))!.qrData, ticket.qrData);

    final offlineTickets = await TicketRepository(storage: reopenedStorage)
        .load(userId: ticket.userId, hasConnection: false);
    expect(offlineTickets.isOffline, isTrue);
    expect(offlineTickets.savedIds, contains(ticket.id));
    expect(offlineTickets.tickets.single.qrData, ticket.qrData);

    await reopenedStorage.updateTicket(
      Ticket(
        id: ticket.id,
        userId: ticket.userId,
        eventName: 'Updated concert',
        date: ticket.date,
        venue: ticket.venue,
        status: 'Used',
        qrData: ticket.qrData,
        price: 3000,
      ),
    );
    final updated = (await reopenedStorage.getTicket(ticket.id))!;
    expect(updated.eventName, 'Updated concert');
    expect(updated.status, 'Used');
    expect(updated.downloadedAt, stored.downloadedAt);

    await reopenedStorage.deleteTicket(ticket.id, userId: ticket.userId);
    expect(await reopenedStorage.getTicket(ticket.id), isNull);
    await reopenedStorage.close();
    await databaseFactory.deleteDatabase(
      path.join(await getDatabasesPath(), databaseName),
    );
  });

  test('SQLite ticket sync updates and isolates records by user', () async {
    final storage = TicketStorage(databasePath: ':memory:');
    final firstUserTicket = _ticket('ticket-1', 'user-1');
    final secondUserTicket = _ticket('ticket-1', 'user-2');
    await storage.saveTickets([firstUserTicket, secondUserTicket]);

    await storage.synchronizeUserTickets('user-1', [
      firstUserTicket.copyWith(status: 'Used'),
      firstUserTicket.copyWith(status: 'Used'),
    ]);

    final firstUserTickets = await storage.getSavedTickets(userId: 'user-1');
    final secondUserTickets = await storage.getSavedTickets(userId: 'user-2');

    expect(firstUserTickets, hasLength(1));
    expect(firstUserTickets.single.status, 'Used');
    expect(secondUserTickets.single.userId, secondUserTicket.userId);
    expect(secondUserTickets.single.status, secondUserTicket.status);
    expect(secondUserTickets.single.qrData, secondUserTicket.qrData);
    expect(await storage.getLastSynced(userId: 'user-1'), isNotNull);
    await storage.close();
  });
}

Ticket _ticket(String id, String userId) => Ticket(
  id: id,
  userId: userId,
  eventName: 'Event',
  date: '2027-01-01',
  venue: 'Lilongwe',
  status: 'Issued',
  qrData: 'unique-$id',
);
