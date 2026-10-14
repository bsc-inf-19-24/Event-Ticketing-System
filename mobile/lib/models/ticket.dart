
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
  };

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      eventName: json['eventName'] as String,
      date: json['date'] as String,
      venue: json['venue'] as String,
      status: json['status'] as String,
      qrData: json['qrData'] as String,
      ticketType: (json['ticketType'] as String?) ?? 'Standard',
      price: (json['price'] as num?)?.toInt() ?? 0,
      purchasedOn: (json['purchasedOn'] as String?) ?? '',
      imagePath: (json['imagePath'] as String?) ?? '',
    );
  }
}
