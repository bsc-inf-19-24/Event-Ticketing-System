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
  final String downloadedAt;
  final String userId;
  final String paymentId;
  final bool used;
  final String orderId;
  final String buyerName;
  final String buyerEmail;
  final String paymentStatus;
  final String source;

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
    this.downloadedAt = '',
    this.userId = '',
    this.paymentId = '',
    this.used = false,
    this.orderId = '',
    this.buyerName = '',
    this.buyerEmail = '',
    this.paymentStatus = '',
    this.source = 'local',
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

  String get qrPayload => qrData;

  bool get isIssued {
    const unavailableStatuses = {
      'pending',
      'failed',
      'cancelled',
      'canceled',
      'refunded',
      'void',
      'revoked',
    };
    const paidStatuses = {
      'paid',
      'success',
      'successful',
      'completed',
      'complete',
      'confirmed',
      'settled',
    };
    if (unavailableStatuses.contains(status.toLowerCase())) return false;
    return paymentStatus.isEmpty ||
        paidStatuses.contains(paymentStatus.toLowerCase());
  }

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
    'downloadedAt': downloadedAt,
    'userId': userId,
    'paymentId': paymentId,
    'used': used,
    'orderId': orderId,
    'buyerName': buyerName,
    'buyerEmail': buyerEmail,
    'paymentStatus': paymentStatus,
    'source': source,
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
      downloadedAt: _stringValue(json['downloadedAt']),
      userId: _stringValue(json['userId']),
      paymentId: _stringValue(json['paymentId']),
      used: json['used'] as bool? ?? false,
      orderId: _stringValue(json['orderId']),
      buyerName: _stringValue(json['buyerName']),
      buyerEmail: _stringValue(json['buyerEmail']),
      paymentStatus: _stringValue(json['paymentStatus']),
      source: _stringValue(json['source'], fallback: 'local'),
    );
  }

  factory Ticket.fromApiJson(
    Map<String, dynamic> json, {
    required String authenticatedUserId,
    String? imageBaseUrl,
  }) {
    final event = _nestedMap(json['event']);
    final ticketTypeData = _nestedMap(
      json['ticketType'] ?? json['ticket_type'],
    );
    final payment = _nestedMap(json['payment']);
    final order = _nestedMap(json['order']);
    final customer = _nestedMap(
      json['customer'] ?? json['user'] ?? json['owner'],
    );
    final qr =
        json['qrCode'] ??
        json['qr_code'] ??
        json['qrCodeData'] ??
        json['qr_code_data'] ??
        json['qrCodeUrl'] ??
        json['qr_code_url'] ??
        json['qrData'] ??
        json['qr_data'] ??
        json['qr'];
    final ownerId = _firstString([
      json['userId'],
      json['user_id'],
      json['customerId'],
      json['customer_id'],
      customer['id'],
    ]);

    return Ticket(
      id: _firstString([
        json['id'],
        json['_id'],
        json['ticketId'],
        json['ticket_id'],
      ]),
      eventName: _firstString([
        json['eventName'],
        json['event_name'],
        event['name'],
        event['title'],
      ], fallback: 'Event'),
      date: _firstString([
        json['date'],
        json['eventDate'],
        json['event_date'],
        event['date'],
        event['startsAt'],
        event['starts_at'],
        event['startDate'],
        event['start_date'],
      ]),
      venue: _firstString([
        json['venue'],
        json['eventVenue'],
        json['event_venue'],
        event['venue'],
        _nestedMap(event['location'])['name'],
      ]),
      status: _firstString([
        json['status'],
        json['ticketStatus'],
        json['ticket_status'],
      ], fallback: 'Issued'),
      qrData: _qrString(json['qrContent'] ?? json['qr_content'] ?? qr),
      ticketType: _firstString([
        json['ticketTypeName'],
        json['ticket_type_name'],
        json['ticketType'],
        json['ticket_type'],
        ticketTypeData['name'],
        ticketTypeData['title'],
      ], fallback: 'Standard'),
      price: _intValue([
        json['price'],
        json['amount'],
        ticketTypeData['price'],
      ]),
      purchasedOn: _firstString([
        json['purchasedOn'],
        json['purchased_on'],
        json['issuedAt'],
        json['issued_at'],
        json['createdAt'],
        json['created_at'],
      ]),
      imagePath: _resolveServerImagePath(
        _firstString([
          json['imagePath'],
          json['image_path'],
          json['coverImagePath'],
          json['cover_image_path'],
          event['imagePath'],
          event['image_path'],
          event['coverImagePath'],
          event['cover_image_path'],
          event['image'],
        ]),
        imageBaseUrl,
      ),
      userId: ownerId.isEmpty ? authenticatedUserId : ownerId,
      paymentId: _firstString([
        json['paymentId'],
        json['payment_id'],
        payment['id'],
        payment['transactionId'],
        payment['transaction_id'],
      ]),
      used: _boolValue([json['used'], json['isUsed'], json['is_used']]),
      orderId: _firstString([json['orderId'], json['order_id'], order['id']]),
      buyerName: _firstString([
        json['buyerName'],
        json['buyer_name'],
        customer['name'],
      ]),
      buyerEmail: _firstString([
        json['buyerEmail'],
        json['buyer_email'],
        customer['email'],
      ]),
      paymentStatus: _firstString([
        json['paymentStatus'],
        json['payment_status'],
        payment['status'],
        order['paymentStatus'],
        order['payment_status'],
      ]),
    );
  }

  factory Ticket.fromServer(
    Map<String, dynamic> json, {
    required String authenticatedUserId,
    String? imageBaseUrl,
  }) {
    final parsed = Ticket.fromApiJson(
      json,
      authenticatedUserId: authenticatedUserId,
      imageBaseUrl: imageBaseUrl,
    );
    return parsed.copyWith(source: 'server');
  }

  Ticket copyWith({
    String? id,
    String? eventName,
    String? date,
    String? venue,
    String? status,
    String? qrData,
    String? ticketType,
    int? price,
    String? purchasedOn,
    String? imagePath,
    String? downloadedAt,
    String? userId,
    String? paymentId,
    bool? used,
    String? orderId,
    String? buyerName,
    String? buyerEmail,
    String? paymentStatus,
    String? source,
  }) => Ticket(
    id: id ?? this.id,
    eventName: eventName ?? this.eventName,
    date: date ?? this.date,
    venue: venue ?? this.venue,
    status: status ?? this.status,
    qrData: qrData ?? this.qrData,
    ticketType: ticketType ?? this.ticketType,
    price: price ?? this.price,
    purchasedOn: purchasedOn ?? this.purchasedOn,
    imagePath: imagePath ?? this.imagePath,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    userId: userId ?? this.userId,
    paymentId: paymentId ?? this.paymentId,
    used: used ?? this.used,
    orderId: orderId ?? this.orderId,
    buyerName: buyerName ?? this.buyerName,
    buyerEmail: buyerEmail ?? this.buyerEmail,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    source: source ?? this.source,
  );
}

String _resolveServerImagePath(String imagePath, String? baseUrl) {
  if (imagePath.isEmpty || imagePath.startsWith('assets/')) return imagePath;
  final uri = Uri.tryParse(imagePath);
  if (uri != null && uri.hasScheme) return imagePath;
  if (baseUrl == null || baseUrl.isEmpty) return imagePath;
  return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/')
      .resolve(imagePath)
      .toString();
}

String _stringValue(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;

Map<String, dynamic> _nestedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _firstString(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return fallback;
}

String _qrString(dynamic value) {
  if (value is String) return value.trim();
  final data = _nestedMap(value);
  return _firstString([
    data['data'],
    data['value'],
    data['content'],
    data['text'],
    data['url'],
  ]);
}

int _intValue(List<dynamic> values) {
  for (final value in values) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed.toInt();
    }
  }
  return 0;
}

bool _boolValue(List<dynamic> values) {
  for (final value in values) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true' || value.toLowerCase() == 'used') {
        return true;
      }
      if (value.toLowerCase() == 'false' || value.toLowerCase() == 'unused') {
        return false;
      }
    }
  }
  return false;
}
