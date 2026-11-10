/// A selected ticket type and quantity in an order.
class OrderItem {
  const OrderItem({
    required this.ticketTypeName,
    required this.unitPrice,
    required this.quantity,
    this.ticketTypeId,
  });

  final String? ticketTypeId;
  final String ticketTypeName;
  final int unitPrice;
  final int quantity;

  Map<String, dynamic> toJson() => {
    if (ticketTypeId != null) 'ticketTypeId': ticketTypeId,
    'ticketTypeName': ticketTypeName,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  Map<String, dynamic> toOrderRequestJson() => {
    if (ticketTypeId != null) 'ticketTypeId': int.tryParse(ticketTypeId!) ?? ticketTypeId,
    'quantity': quantity,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    ticketTypeId: _nullableString(json['ticketTypeId']),
    ticketTypeName: _stringValue(json['ticketTypeName'], fallback: 'Standard'),
    unitPrice: json['unitPrice'] is num
        ? (json['unitPrice'] as num).toInt()
        : 0,
    quantity: json['quantity'] is num ? (json['quantity'] as num).toInt() : 0,
  );
}

/// A locally persisted ticket purchase.
class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.eventTitle,
    required this.eventVenue,
    required this.eventDate,
    required this.items,
    required this.total,
    required this.status,
    required this.txRef,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String eventTitle;
  final String eventVenue;
  final String eventDate;
  final List<OrderItem> items;
  final int total;
  final String status;
  final String txRef;
  final String paymentMethod;
  final DateTime createdAt;

  Order copyWith({String? status, String? txRef, int? total}) => Order(
    id: id,
    userId: userId,
    eventTitle: eventTitle,
    eventVenue: eventVenue,
    eventDate: eventDate,
    items: items,
    total: total ?? this.total,
    status: status ?? this.status,
    txRef: txRef ?? this.txRef,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'eventTitle': eventTitle,
    'eventVenue': eventVenue,
    'eventDate': eventDate,
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'status': status,
    'txRef': txRef,
    'paymentMethod': paymentMethod,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => OrderItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <OrderItem>[];
    final rawStatus = json['status'];
    final status = rawStatus is String ? rawStatus : 'pending';
    final rawCreatedAt = json['createdAt'];
    return Order(
      id: _stringValue(json['id']),
      userId: _stringValue(json['userId']),
      eventTitle: _stringValue(json['eventTitle'], fallback: 'Event'),
      eventVenue: _stringValue(json['eventVenue']),
      eventDate: _stringValue(json['eventDate']),
      items: items,
      total: _intValue(json['totalAmount'] ?? json['total_amount'] ?? json['total']),
      status: const {'pending', 'paid', 'failed', 'cancelled'}.contains(status)
          ? status
          : 'pending',
      txRef: _stringValue(json['txRef']),
      paymentMethod: _stringValue(json['paymentMethod'], fallback: 'card'),
      createdAt:
          DateTime.tryParse(rawCreatedAt is String ? rawCreatedAt : '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  final parsed = num.tryParse('$value');
  return parsed?.toInt() ?? 0;
}

String _stringValue(dynamic value, {String fallback = ''}) =>
    value is String ? value : value is num ? value.toString() : fallback;

String? _nullableString(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
