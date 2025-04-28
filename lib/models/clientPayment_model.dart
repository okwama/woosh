class ClientPayment {
  final int id;
  final int clientId;
  final double amount;
  final String? imageUrl;
  final DateTime date;
  final String? status;

  ClientPayment({
    required this.id,
    required this.clientId,
    required this.amount,
    this.imageUrl,
    required this.date,
    this.status,
  });

  factory ClientPayment.fromJson(Map<String, dynamic> json) {
    return ClientPayment(
      id: json['id'],
      clientId: json['clientId'],
      amount: (json['amount'] as num).toDouble(),
      imageUrl: json['imageUrl'],
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'amount': amount,
      'imageUrl': imageUrl,
      'date': date.toIso8601String(),
      'status': status,
    };
  }
}
