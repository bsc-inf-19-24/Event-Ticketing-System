import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/ticket.dart';
import 'package:mobile/services/ticket_storage.dart';

void main() {
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
    expect(secondUserTickets.single.toJson(), secondUserTicket.toJson());
    expect(await storage.getLastSynced(userId: 'user-1'), isNotNull);
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
