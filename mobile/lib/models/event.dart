import 'package:intl/intl.dart';

class TicketType {
  final String? id;
  final String name;
  final int price;
  final int? remainingInventory;
  final String status;

  const TicketType({
    this.id,
    required this.name,
    required this.price,
    this.remainingInventory,
    this.status = 'Available',
  });

  bool get isAvailable =>
      _isPurchasableStatus(status) &&
      (remainingInventory == null || remainingInventory! > 0);
}

class Event {
  final String? id;
  final String title;
  final String date;
  final String time;
  final String venue;
  final String location;
  final int price;
  final String imagePath;
  final String category;
  final String genre;
  final String? endTime;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final List<TicketType> ticketTypes;
  final int capacity;
  final String availability;

  const Event({
    this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    this.location = '',
    required this.price,
    required this.imagePath,
    required this.category,
    this.genre = '',
    this.endTime,
    this.startDateTime,
    this.endDateTime,
    this.ticketTypes = const [],
    this.capacity = 0,
    String status = 'AVAILABLE',
    String? availability,
  }) : availability = availability ?? status;

  bool get hasStart =>
      startDateTime != null ||
      DateTime.tryParse(date) != null ||
      (date.trim().isNotEmpty && !_looksLikeIsoDate(date));

  String get displayDate {
    final start = startDateTime ?? DateTime.tryParse(date);
    if (start != null) return DateFormat('EEEE, d MMMM yyyy').format(start);
    return _looksLikeIsoDate(date) ? '' : date;
  }

  String get displayStartTime {
    final start = startDateTime ?? DateTime.tryParse(date);
    if (start != null) return DateFormat('h:mm a').format(start);
    if (!hasStart) return '';
    return _looksLikeIsoDate(time) ? '' : time;
  }

  String get displayEndTime {
    final end = endDateTime ?? DateTime.tryParse(endTime ?? '');
    if (end != null) return DateFormat('h:mm a').format(end);
    final value = endTime ?? '';
    return _looksLikeIsoDate(value) ? '' : value;
  }

  String get timeRange {
    final start = displayStartTime;
    if (start.isEmpty) return '';
    final end = displayEndTime;
    return end.isEmpty ? start : '$start - $end';
  }

  String get place => [venue, location]
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');

  String get displayGenre {
    if (genre.trim().isNotEmpty) return genre.trim();
    return switch (category.trim().toLowerCase()) {
      'concerts' => 'Music & Entertainment',
      'sports' => 'Sports',
      'workshop' => 'Workshop',
      'festival' => 'Festival',
      _ => category.trim(),
    };
  }

  String get statusLabel => switch (availability.trim().toUpperCase()) {
    'AVAILABLE' || 'PUBLISHED' || 'ACTIVE' => 'Available',
    'SOLD_OUT' || 'SOLD OUT' => 'Sold out',
    'ENDED' => 'Ended',
    'CANCELLED' || 'CANCELED' => 'Cancelled',
    _ => 'Unavailable',
  };

  String get status => availability;

  bool get isAvailable =>
      const {'AVAILABLE', 'PUBLISHED', 'ACTIVE'}.contains(
        availability.trim().toUpperCase(),
      );
}

bool _looksLikeIsoDate(String value) =>
    RegExp(r'^\\d{4}-\\d{2}-\\d{2}').hasMatch(value.trim());

bool _isPurchasableStatus(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  return const {
    'available',
    'published',
    'active',
    'open',
    'on_sale',
    'onsale',
    'selling',
  }.contains(normalized);
}
