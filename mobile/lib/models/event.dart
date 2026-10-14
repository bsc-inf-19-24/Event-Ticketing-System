class TicketType {
  final String name;
  final int price;

  const TicketType({required this.name, required this.price});
}

class Event {
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
}
