
class Ticket {
  final String id;
  final String eventName;
  final String date;
  final String venue;
  final String status;
  final String qrData;

  const Ticket({
    required this.id,
    required this.eventName,
    required this.date,
    required this.venue,
    required this.status,
    required this.qrData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventName': eventName,
    'date': date,
    'venue': venue,
    'status': status,
    'qrData': qrData,
  };

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      eventName: json['eventName'] as String,
      date: json['date'] as String,
      venue: json['venue'] as String,
      status: json['status'] as String,
      qrData: json['qrData'] as String,
    );
  }
}
