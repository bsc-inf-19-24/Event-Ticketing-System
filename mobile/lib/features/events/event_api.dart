import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_endpoints.dart';
import '../../models/event.dart';

class EventApi {
  EventApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<Event>> list({String? category, String? search}) async {
    final query = <String, String>{
      if (category != null && category.trim().isNotEmpty) 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _client.get(
      '${ApiEndpoints.events}${query.isEmpty ? '' : '?${Uri(queryParameters: query).query}'}',
    );
    final values = _listResponse(response, 'events');
    return values
        .map((value) => _event(_map(value), baseUrl: _client.effectiveBaseUrl))
        .toList();
  }

  Future<Event> details(String id) async {
    final response = await _client.get(
      ApiEndpoints.event(Uri.encodeComponent(id)),
    );
    final data = _objectResponse(response, 'event');
    return _event(data, baseUrl: _client.effectiveBaseUrl);
  }
}

Event _event(Map<String, dynamic> data, {required String baseUrl}) {
  final types = data['ticketTypes'] ?? data['ticket_types'] ?? data['tickets'];
  final startText = _first(data, [
    'startTime',
    'dateTime',
    'date',
    'eventDate',
    'startDate',
    'startsAt',
    'starts_at',
  ]);
  final parsedStart = DateTime.tryParse(startText);
  final endText = _first(data, ['endTime', 'endDate', 'endsAt', 'ends_at']);
  final parsedEnd = DateTime.tryParse(endText);
  final cover = _first(data, [
    'coverImagePath',
    'imagePath',
    'image',
    'cover_image_path',
  ]);
  final coverUri = Uri.tryParse(cover);
  return Event(
    id: _first(data, ['id', 'eventId', 'event_id']),
    title: _first(data, ['title', 'name'], fallback: 'Event'),
    date: parsedStart != null
        ? DateFormat('EEEE, d MMMM yyyy').format(parsedStart)
        : RegExp(r'^\\d{4}-\\d{2}-\\d{2}').hasMatch(startText)
        ? ''
        : startText,
    time: parsedStart == null ? '' : DateFormat('h:mm a').format(parsedStart),
    startDateTime: parsedStart,
    endDateTime: parsedEnd,
    venue: _first(data, ['venue', 'venueName']),
    location: _first(data, ['location']),
    price: _integer(data['minPrice'] ?? data['price']),
    imagePath: cover.isEmpty || (coverUri?.hasScheme ?? false)
        ? cover
        : Uri.parse('$baseUrl/').resolve(cover).toString(),
    category: _first(data, ['category', 'categoryName']),
    genre: _first(data, ['genre']),
    endTime: endText,
    ticketTypes: types is List
        ? types
              .whereType<Map>()
              .map((value) => _ticketType(_map(value)))
              .toList()
        : const [],
    capacity: _integer(data['capacity']),
    availability: _availability(data),
  );
}

TicketType _ticketType(Map<String, dynamic> data) => TicketType(
  id: _first(data, ['id', 'ticketTypeId', 'ticket_type_id']),
  name: _first(data, ['name', 'title'], fallback: 'Ticket'),
  price: _integer(data['price']),
  remainingInventory: _nullableInteger(
    data['remainingInventory'] ??
        data['remaining_inventory'] ??
        data['remaining'] ??
        data['availableQuantity'] ??
        data['available_quantity'] ??
        data['quantityAvailable'] ??
        data['quantity_available'] ??
        data['quantity'],
  ),
  status: _first(data, [
    'status',
    'availability',
    'saleStatus',
    'sale_status',
  ], fallback: 'Available'),
);



String _availability(Map<String, dynamic> data) {
  final explicit = _first(data, ['availability']);
  if (explicit.isNotEmpty) return explicit;
  final legacyStatus = _first(data, ['status'], fallback: 'UNAVAILABLE');
  return const {'PUBLISHED', 'ACTIVE'}.contains(legacyStatus.toUpperCase())
      ? 'AVAILABLE'
      : legacyStatus;
}

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int? _nullableInteger(dynamic value) => value == null ? null : _integer(value);
String _first(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    if (key == 'location' && value is Map) {
      final location = value['name'] ?? value['address'];
      if (location is String) return location;
    }
  }
  return fallback;
}

Map<String, dynamic> _objectResponse(dynamic response, String name) {
  dynamic value = response;
  for (var i = 0; i < 3 && value is Map; i++) {
    final map = Map<String, dynamic>.from(value);
    final nested = map['data'] ?? map[name];
    if (nested is! Map) return map;
    value = nested;
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  throw ApiException('The server returned invalid $name data.');
}

List<dynamic> _listResponse(dynamic response, String name) {
  dynamic value = response;
  for (var i = 0; i < 3 && value is Map; i++) {
    final map = Map<String, dynamic>.from(value);
    value = map['data'] ?? map[name] ?? map['items'] ?? map['content'];
  }
  if (value is List) return value;
  throw ApiException('The server returned invalid $name data.');
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}
