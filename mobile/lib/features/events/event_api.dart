import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_endpoints.dart';
import '../../models/event.dart';
import '../../utils/server_image_url.dart';

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
    final events = values
        .map((value) => _event(_map(value), baseUrl: _client.effectiveBaseUrl))
        .toList();
    // The events endpoint has no bulk ticket pricing. Enrich only events whose
    // list response has no usable price, with a small concurrency limit.
    for (var start = 0; start < events.length; start += 4) {
      final batch = events.skip(start).take(4).toList();
      events.replaceRange(
        start,
        start + batch.length,
        await Future.wait(batch.map(_loadStartingPrice)),
      );
    }
    return events;
  }

  Future<Event> _loadStartingPrice(Event event) async {
    final id = event.id;
    if (event.hasPrice || id == null || id.isEmpty) return event;
    try {
      final response = await _client.get(
        ApiEndpoints.ticketTypes(Uri.encodeComponent(id)),
      );
      final ticketTypes = _ticketTypes(_listResponse(response, 'ticketTypes'));
      final startingPrice = _lowestTicketPrice(ticketTypes);
      if (startingPrice == null) return event;
      return event.copyWith(price: startingPrice, hasPrice: true);
    } catch (_) {
      // A missing price should not prevent the event list from loading.
      return event;
    }
  }

  Future<Event> details(String id) async {
    final response = await _client.get(
      ApiEndpoints.event(Uri.encodeComponent(id)),
    );
    final data = _objectResponse(response, 'event');
    var event = _event(data, baseUrl: _client.effectiveBaseUrl);
    if (event.ticketTypes.isEmpty) {
      try {
        final ticketResponse = await _client.get(
          ApiEndpoints.ticketTypes(Uri.encodeComponent(id)),
        );
        final ticketTypes = _ticketTypes(
          _listResponse(ticketResponse, 'ticketTypes'),
        );
        final startingPrice = _lowestTicketPrice(ticketTypes);
        final directPrice = _eventPrice(data);
        event = event.copyWith(
          ticketTypes: ticketTypes,
          price: directPrice ?? startingPrice ?? event.price,
          hasPrice: directPrice != null || startingPrice != null,
        );
      } catch (_) {
        // Keep event details usable when the ticket-types endpoint is unavailable.
      }
    }
    return event;
  }
}

Event _event(Map<String, dynamic> data, {required String baseUrl}) {
  final types = data['ticketTypes'] ?? data['ticket_types'] ?? data['tickets'];
  final directPrice = _eventPrice(data);
  final ticketTypes = types is List
      ? _ticketTypes(types)
      : const <TicketType>[];
  final startingPrice = _lowestTicketPrice(ticketTypes);
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
  final cover = _eventCover(data, baseUrl);
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
    price: directPrice ?? startingPrice ?? 0,
    hasPrice: directPrice != null || startingPrice != null,
    imagePath: cover,
    description: _first(data, ['description']),
    category: _first(data, ['category', 'categoryName']),
    genre: _first(data, ['genre']),
    endTime: endText,
    ticketTypes: ticketTypes,
    capacity: _integer(data['capacity']),
    availability: _availability(data),
  );
}

String _eventCover(Map<String, dynamic> data, String baseUrl) {
  dynamic value;
  for (final key in const [
    'coverImagePath',
    'cover_image_path',
    'coverImageUrl',
    'cover_image_url',
    'imagePath',
    'image_path',
    'imageUrl',
    'image_url',
    'coverImage',
    'cover_image',
    'bannerImagePath',
    'banner_image_path',
    'posterUrl',
    'poster_url',
    'image',
  ]) {
    final candidate = data[key];
    if (candidate is String && candidate.trim().isNotEmpty) {
      value = candidate.trim();
      break;
    }
    if (candidate is Map) {
      for (final nestedKey in const ['url', 'path', 'src', 'href']) {
        final nested = candidate[nestedKey];
        if (nested is String && nested.trim().isNotEmpty) {
          value = nested.trim();
          break;
        }
      }
      if (value != null) break;
    }
  }
  if (value == null) return '';

  return resolveServerImageUrl(value as String, baseUrl);
}

List<TicketType> _ticketTypes(List<dynamic> values) => values
    .whereType<Map>()
    .where((value) => _priceValue(value['price']) != null)
    .map((value) => _ticketType(_map(value)))
    .toList();

int? _lowestTicketPrice(List<TicketType> ticketTypes) {
  if (ticketTypes.isEmpty) return null;
  return ticketTypes
      .map((ticket) => ticket.price)
      .reduce((lowest, price) => price < lowest ? price : lowest);
}

int? _eventPrice(Map<String, dynamic> data) =>
    _priceValue(data['minPrice']) ?? _priceValue(data['price']);

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
  final status = _first(data, ['status']);
  if (const {'CANCELLED', 'CANCELED'}.contains(status.toUpperCase())) {
    return status;
  }
  final explicit = _first(data, ['availability']);
  if (explicit.isNotEmpty) return explicit;
  final legacyStatus = _first(data, ['status'], fallback: 'UNAVAILABLE');
  return const {'PUBLISHED', 'ACTIVE'}.contains(legacyStatus.toUpperCase())
      ? 'AVAILABLE'
      : legacyStatus;
}

int _integer(dynamic value) => _priceValue(value) ?? 0;
int? _priceValue(dynamic value) {
  final parsed = value is num ? value : num.tryParse('${value ?? ''}');
  if (parsed == null || !parsed.isFinite || parsed < 0) return null;
  return parsed.toInt();
}

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
