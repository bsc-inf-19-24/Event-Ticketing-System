import '../data/sample_tickets.dart';
import '../models/ticket.dart';
import 'ticket_storage.dart';

class TicketListResult {
  final List<Ticket> tickets;
  final Set<String> savedIds;
  final bool isOffline;
  final DateTime? lastSynced;

  const TicketListResult({
    required this.tickets,
    required this.savedIds,
    required this.isOffline,
    this.lastSynced,
  });
}

class TicketRepository {
  TicketRepository({TicketStorage? storage})
      : _storage = storage ?? TicketStorage();

  final TicketStorage _storage;

  /// Swap this for the real API call later. Throw on failure.
  Future<List<Ticket>> fetchRemoteTickets() async => sampleTickets;

  Future<TicketListResult> load({required bool hasConnection}) async {
    if (hasConnection) {
      try {
        final remote = await fetchRemoteTickets();
        await _storage.refreshSavedTickets(remote); // refresh local copies
        final saved = await _storage.getSavedTickets();
        final savedIds = saved.map((t) => t.id).toSet();

        // Remote is the source of truth; keep saved tickets that the
        // server no longer lists so they don't silently vanish.
        final byId = {for (final t in remote) t.id: t};
        for (final t in saved) {
          byId.putIfAbsent(t.id, () => t);
        }

        return TicketListResult(
          tickets: byId.values.toList(),
          savedIds: savedIds,
          isOffline: false,
          lastSynced: await _storage.getLastSynced(),
        );
      } catch (_) {
        // Backend unreachable: fall through to offline mode.
      }
    }

    final saved = await _storage.getSavedTickets();
    return TicketListResult(
      tickets: saved,
      savedIds: saved.map((t) => t.id).toSet(),
      isOffline: true,
      lastSynced: await _storage.getLastSynced(),
    );
  }
}