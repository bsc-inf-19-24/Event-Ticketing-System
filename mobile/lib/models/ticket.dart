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
  final String orderId;
  final String buyerName;
  final String buyerEmail;

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
    this.orderId = '',
    this.buyerName = '',
    this.buyerEmail = '',
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
    'orderId': orderId,
    'buyerName': buyerName,
    'buyerEmail': buyerEmail,
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
       paymentId: (json['paymentId'] as String?) ?? '',
      orderId: (json['orderId'] as String?) ?? '',
      buyerName: (json['buyerName'] as String?) ?? '',
      buyerEmail: (json['buyerEmail'] as String?) ?? '',
      paymentId: _stringValue(json['paymentId']),
      used: json['used'] as bool? ?? false,
      orderId: _stringValue(json['orderId']),
      buyerName: _stringValue(json['buyerName']),
      buyerEmail: _stringValue(json['buyerEmail']),
    );
  }
}

String _stringValue(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;
