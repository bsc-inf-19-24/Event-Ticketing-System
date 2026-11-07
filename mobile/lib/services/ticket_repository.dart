import '../core/network/api_client.dart';
import '../features/tickets/data/ticket_api.dart';
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
  TicketRepository({TicketStorage? storage, TicketApi? api})
    : _storage = storage ?? TicketStorage(),
      _api = api ?? _configuredApi();

  final TicketStorage _storage;
  final TicketApi? _api;

  static TicketApi? _configuredApi() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    if (baseUrl.isEmpty) return null;
    return TicketApi(apiClient: ApiClient(baseUrl: baseUrl));
  }

  Future<TicketListResult> load({
    required String userId,
    required bool hasConnection,
  }) async {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');

    final api = _api;
    if (hasConnection && api != null) {
      try {
        final remote = await api.getMyTickets(userId);
        await _storage.synchronizeUserTickets(userId, remote);
        return TicketListResult(
          tickets: remote.reversed.toList(),
          savedIds: remote.map((ticket) => ticket.id).toSet(),
          isOffline: false,
          lastSynced: DateTime.now(),
        );
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) rethrow;
        final cached = await _storage.getSavedTickets(userId: userId);
        if (cached.isEmpty) rethrow;
        return TicketListResult(
          tickets: cached.reversed.toList(),
          savedIds: cached.map((ticket) => ticket.id).toSet(),
          isOffline: true,
          lastSynced: await _storage.getLastSynced(userId: userId),
        );
      }
    }

    final cached = await _storage.getSavedTickets(userId: userId);
    return TicketListResult(
      tickets: cached.reversed.toList(),
      savedIds: cached.map((ticket) => ticket.id).toSet(),
      isOffline: api != null && !hasConnection,
      lastSynced: await _storage.getLastSynced(userId: userId),
    );
  }

  Future<Ticket> getTicketDetails({
    required String ticketId,
    required String userId,
    required bool hasConnection,
  }) async {
    if (ticketId.isEmpty || userId.isEmpty) {
      throw ArgumentError('Ticket ID and authenticated user ID are required.');
    }

    final api = _api;
    if (hasConnection && api != null) {
      final ticket = await api.getTicketDetails(
        ticketId,
        authenticatedUserId: userId,
      );
      await _storage.saveTickets([ticket]);
      return ticket;
    }

    final saved = await _storage.getSavedTickets(userId: userId);
    return saved.firstWhere(
      (ticket) => ticket.id == ticketId,
      orElse: () =>
          throw ApiException('This ticket is not saved on this device.'),
    );
  }

  Future<void> saveTickets(List<Ticket> tickets) =>
      _storage.saveTickets(tickets);
}
