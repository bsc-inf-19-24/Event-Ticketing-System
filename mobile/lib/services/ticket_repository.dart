import '../core/network/api_client.dart';
import '../features/tickets/data/ticket_api.dart';
import '../features/payment/services/api_payment_service.dart';
import '../features/payment/services/fake_payment_service.dart';
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
  TicketRepository({TicketStorage? storage, TicketApi? api, this.ordersApi})
    : _storage = storage ?? TicketStorage(),
      _api =
          api ??
          (useFakeTickets
              ? _configuredApi()
              : TicketApi(apiClient: ApiClient.instance));

  final TicketStorage _storage;
  final TicketApi? _api;
  final ApiPaymentService? ordersApi;

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

    final cached = await _storage.getSavedTickets(userId: userId);
    final api = _api;
    if (hasConnection && api != null) {
      try {
        final remote = await api.getMyTickets(userId);
        if (remote.isEmpty && cached.isNotEmpty) {
          return TicketListResult(
            tickets: cached.reversed.toList(),
            savedIds: cached.map((ticket) => ticket.id).toSet(),
            isOffline: true,
            lastSynced: await _storage.getLastSynced(userId: userId),
          );
        }
        await _storage.synchronizeUserTickets(userId, remote);
        return TicketListResult(
          tickets: remote.reversed.toList(),
          savedIds: remote.map((ticket) => ticket.id).toSet(),
          isOffline: false,
          lastSynced: DateTime.now(),
        );
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) rethrow;
        if (cached.isEmpty) rethrow;
        return TicketListResult(
          tickets: cached.reversed.toList(),
          savedIds: cached.map((ticket) => ticket.id).toSet(),
          isOffline: true,
          lastSynced: await _storage.getLastSynced(userId: userId),
        );
      }
    }

    final paymentApi = useFakeTickets ? ordersApi : null;
    if (useFakeTickets && hasConnection && paymentApi != null) {
      try {
        final orders = await paymentApi.getMyOrders();
        final remote = <Ticket>[];
        final ids = <String>{};
        for (final order in orders) {
          final orderOwnerId = _ownerId(order);
          if (orderOwnerId != null && orderOwnerId != userId) continue;
          final status = _stringValue([
            order['status'],
            order['paymentStatus'],
            order['payment_status'],
          ]).toLowerCase();
          if (!const {
            'paid',
            'success',
            'successful',
            'completed',
            'confirmed',
            'settled',
          }.contains(status)) {
            continue;
          }
          for (final value in _ticketValues(order)) {
            final ticketOwnerId = ticketOwnerIdFromJson(value);
            if (ticketOwnerId != null && ticketOwnerId != userId) continue;
            if (ticketOwnerId == null && orderOwnerId == null) continue;
            final ticket = Ticket.fromServer(
              value,
              authenticatedUserId: userId,
              imageBaseUrl: paymentApi.effectiveBaseUrl,
            );
            if (ticket.id.isEmpty) {
              throw const ApiException(
                'The server returned a ticket without an ID.',
              );
            }
            if (ticket.userId != userId) continue;
            if (ticket.isIssued && ids.add(ticket.id)) remote.add(ticket);
          }
        }
        await _storage.synchronizeUserTickets(userId, remote);
        return TicketListResult(
          tickets: remote.reversed.toList(),
          savedIds: remote.map((ticket) => ticket.id).toSet(),
          isOffline: false,
          lastSynced: DateTime.now(),
        );
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) rethrow;
        if (cached.isEmpty) rethrow;
        return TicketListResult(
          tickets: cached.reversed.toList(),
          savedIds: cached.map((ticket) => ticket.id).toSet(),
          isOffline: true,
          lastSynced: await _storage.getLastSynced(userId: userId),
        );
      }
    }

    return TicketListResult(
      tickets: cached.reversed.toList(),
      savedIds: cached.map((ticket) => ticket.id).toSet(),
      isOffline: !hasConnection,
      lastSynced: await _storage.getLastSynced(userId: userId),
    );
  }

  List<Map<String, dynamic>> _ticketValues(Map<String, dynamic> order) {
    final raw = order['tickets'] ?? order['ticket'];
    if (raw is List) {
      return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (raw is Map) return [Map<String, dynamic>.from(raw)];
    final nestedOrder = order['order'];
    if (nestedOrder is Map) {
      return _ticketValues(Map<String, dynamic>.from(nestedOrder));
    }
    return const [];
  }

  String _stringValue(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String? _ownerId(Map<String, dynamic> data) {
    final user = _nestedMap(data['user']);
    final customer = _nestedMap(data['customer']);
    final owner = _nestedMap(data['owner']);
    final nestedOrder = _nestedMap(data['order']);
    final candidates = [
      data['userId'],
      data['user_id'],
      data['customerId'],
      data['customer_id'],
      data['ownerId'],
      data['owner_id'],
      user['id'],
      customer['id'],
      owner['id'],
    ];
    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    if (nestedOrder.isNotEmpty) return _ownerId(nestedOrder);
    return null;
  }

  Map<String, dynamic> _nestedMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

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
