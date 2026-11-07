import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/ticket.dart';

class TicketApi {
  TicketApi({
    required this.apiClient,
    SecureStorageService? storage,
    Future<String?> Function()? tokenProvider,
  }) : _storage = storage ?? SecureStorageService() {
    _tokenProvider = tokenProvider ?? _storage.getToken;
  }

  final ApiClient apiClient;
  final SecureStorageService _storage;
  late final Future<String?> Function() _tokenProvider;

  Future<List<Ticket>> getMyTickets(String authenticatedUserId) async {
    final response = await _get('/api/tickets/my');
    final values = _ticketList(response);
    final tickets = <Ticket>[];
    final ids = <String>{};
    final qrPayloads = <String>{};

    for (final value in values) {
      final ticket = Ticket.fromApiJson(
        _ticketMap(value),
        authenticatedUserId: authenticatedUserId,
      );
      if (ticket.id.isEmpty) {
        throw ApiException('The server returned a ticket without an ID.');
      }
      if (ticket.userId != authenticatedUserId) {
        throw ApiException(
          'The server returned a ticket belonging to another account.',
        );
      }
      if (!ticket.isIssued) continue;
      if (ticket.qrPayload.isNotEmpty &&
          !qrPayloads.add(ticket.qrPayload)) {
        throw ApiException('The server returned duplicate ticket QR data.');
      }
      if (ids.add(ticket.id)) tickets.add(ticket);
    }

    return tickets;
  }

  Future<Ticket> getTicketDetails(
    String ticketId, {
    required String authenticatedUserId,
  }) async {
    final response = await _get(
      '/api/tickets/${Uri.encodeComponent(ticketId)}',
    );
    final body = _ticketDetailsMap(response);
    final ticket = Ticket.fromApiJson(
      body,
      authenticatedUserId: authenticatedUserId,
    );
    if (ticket.id.isEmpty || ticket.id != ticketId) {
      throw ApiException('The server returned different ticket details.');
    }
    if (ticket.userId != authenticatedUserId) {
      throw ApiException(
        'This ticket is not available to the authenticated account.',
      );
    }
    if (!ticket.isIssued) {
      throw ApiException(
        'This ticket has not been issued or is no longer valid.',
      );
    }
    return ticket;
  }

  Future<Ticket> validateTicket(
    String ticketId, {
    required String authenticatedUserId,
    String? qrCode,
  }) async {
    final payload = <String, dynamic>{'ticketId': ticketId};
    if (qrCode != null && qrCode.trim().isNotEmpty) {
      payload['qrCode'] = qrCode;
    }
    final response = await _post('/api/tickets/validate', payload);
    final ticket = _ticketFromApiResponse(
      response,
      authenticatedUserId: authenticatedUserId,
      fallbackId: ticketId,
    );
    return ticket;
  }

  Future<Ticket> cancelTicket(
    String ticketId, {
    required String authenticatedUserId,
  }) async {
    final response = await _post(
      '/api/tickets/${Uri.encodeComponent(ticketId)}/cancel',
      const {},
    );
    final ticket = _ticketFromApiResponse(
      response,
      authenticatedUserId: authenticatedUserId,
      fallbackId: ticketId,
    );
    return ticket;
  }

  Future<dynamic> _get(String endpoint) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Your sign-in session has expired. Please sign in again.',
        401,
      );
    }
    try {
      return await apiClient.get(endpoint, token: token);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _storage.deleteToken();
      rethrow;
    }
  }

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Your sign-in session has expired. Please sign in again.',
        401,
      );
    }
    try {
      return await apiClient.post(endpoint, body, token: token);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _storage.deleteToken();
      rethrow;
    }
  }

  Ticket _ticketFromApiResponse(
    dynamic response, {
    required String authenticatedUserId,
    String? fallbackId,
  }) {
    final body = _ticketDetailsMap(response);
    var ticket = Ticket.fromApiJson(
      body,
      authenticatedUserId: authenticatedUserId,
    );
    if (ticket.id.isEmpty && fallbackId != null && fallbackId.isNotEmpty) {
      ticket = ticket.copyWith(id: fallbackId);
    }
    if (ticket.userId.isEmpty) {
      ticket = ticket.copyWith(userId: authenticatedUserId);
    }
    if (ticket.userId != authenticatedUserId) {
      throw ApiException(
        'This ticket is not available to the authenticated account.',
      );
    }
    return ticket;
  }

  List<dynamic> _ticketList(dynamic response) {
    if (response is List) return response;
    if (response is! Map) {
      throw ApiException('The server returned an invalid ticket list.');
    }
    final body = Map<String, dynamic>.from(response);
    final data = body['data'];
    if (data is List) return data;
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      final tickets = nested['tickets'] ?? nested['data'];
      if (tickets is List) return tickets;
    }
    final tickets = body['tickets'];
    if (tickets is List) return tickets;
    throw ApiException('The server response did not contain a ticket list.');
  }

  Map<String, dynamic> _ticketDetailsMap(dynamic response) {
    if (response is! Map) {
      throw ApiException('The server returned invalid ticket details.');
    }
    var body = Map<String, dynamic>.from(response);
    if (body['data'] is Map) {
      body = Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body['ticket'] is Map) {
      body = Map<String, dynamic>.from(body['ticket'] as Map);
    }
    return body;
  }

  Map<String, dynamic> _ticketMap(dynamic value) {
    if (value is! Map) {
      throw ApiException('The server returned an invalid ticket record.');
    }
    var ticket = Map<String, dynamic>.from(value);
    if (ticket['ticket'] is Map) {
      ticket = Map<String, dynamic>.from(ticket['ticket'] as Map);
    }
    return ticket;
  }
}
