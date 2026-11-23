class Interest {
  const Interest({required this.id, required this.name});

  final int id;
  final String name;

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
    id: _integer(json['id']) ?? 0,
    name: (json['name'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class CustomerInterest {
  const CustomerInterest({this.id, this.customerId, required this.interest});

  final int? id;
  final int? customerId;
  final Interest interest;

  factory CustomerInterest.fromJson(Map<String, dynamic> json) {
    final rawInterest = json['interest'];
    if (rawInterest is! Map) {
      throw const FormatException('Customer interest is missing its interest.');
    }
    return CustomerInterest(
      id: _integer(json['id']),
      customerId: _integer(json['customerId']),
      interest: Interest.fromJson(Map<String, dynamic>.from(rawInterest)),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (customerId != null) 'customerId': customerId,
    'interest': interest.toJson(),
  };
}

int? _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
