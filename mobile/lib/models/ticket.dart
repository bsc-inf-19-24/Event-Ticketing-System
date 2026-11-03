class Ticket {
  final String id;
  final String eventName;
  final String date;
  final String venue;
  final String status;
  final String qrData;
  final String ticketType;
  final int price;
  final String purchasedOn;
  final String imagePath;
  final String userId;

  const Ticket({
    required this.id,
    required this.eventName,
    required this.date,
    required this.venue,
    required this.status,
    required this.qrData,
    this.ticketType = 'Standard',
    this.price = 0,
    this.purchasedOn = '',
    this.imagePath = '',
    this.userId = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventName': eventName,
    'date': date,
    'venue': venue,
    'status': status,
    'qrData': qrData,
    'ticketType': ticketType,
    'price': price,
    'purchasedOn': purchasedOn,
    'imagePath': imagePath,
    'userId': userId,
  };

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: _stringValue(json['id']),
      eventName: _stringValue(json['eventName'], fallback: 'Event'),
      date: _stringValue(json['date']),
      venue: _stringValue(json['venue']),
      status: _stringValue(json['status'], fallback: 'Confirmed'),
      qrData: _stringValue(json['qrData']),
      ticketType: _stringValue(json['ticketType'], fallback: 'Standard'),
      price: json['price'] is num ? (json['price'] as num).toInt() : 0,
      purchasedOn: _stringValue(json['purchasedOn']),
      imagePath: _stringValue(json['imagePath']),
      userId: _stringValue(json['userId']),
    );
  }
}

String _stringValue(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;
