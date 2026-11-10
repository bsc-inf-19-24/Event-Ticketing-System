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
  final int price;
  final String imagePath;
  final String category;

  // New fields for the details screen
  final String genre;
  final String? endTime;
  final List<TicketType> ticketTypes;
  final int capacity;
  final String status;

  const Event({
    this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    required this.price,
    required this.imagePath,
    required this.category,
    this.genre = '',
    this.endTime,
    this.ticketTypes = const [],
    this.capacity = 0,
    this.status = 'Available',
  });

  String get timeRange => endTime != null ? '$time - $endTime' : time;

  bool get isAvailable => _isPurchasableStatus(status);
}

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
