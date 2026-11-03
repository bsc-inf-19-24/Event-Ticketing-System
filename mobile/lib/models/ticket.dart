import 'dart:convert';

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
  final String paymentId;
  final bool used;

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
    this.paymentId = '',
    this.used = false,
  });

  /// Full ticket payload encoded in the QR code for gate scanning.
  /// Later the organizer app will POST this to the backend to mark the ticket used.
  Map<String, dynamic> toScanPayload() => {
    'ticketId': id,
    'userId': userId,
    'paymentId': paymentId,
    'eventName': eventName,
    'ticketType': ticketType,
    'price': price,
    'date': date,
    'venue': venue,
    'status': status,
    'purchasedOn': purchasedOn,
    'used': used,
  };

  String get qrPayload => jsonEncode(toScanPayload());

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
    'paymentId': paymentId,
    'used': used,
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
      userId: (json['userId'] as String?) ?? '',
      paymentId: (json['paymentId'] as String?) ?? '',
      used: json['used'] as bool? ?? false,
    );
  }
}
