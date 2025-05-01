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

  // Factory method for creating a payment request
  static Map<String, dynamic> createPaymentRequest({
    required int clientId,
    required double amount,
  }) {
    return {
      'client_id': clientId, // Server might expect snake_case
      'amount': amount.toString(), // Convert to string to ensure proper format
    };
  }

  factory ClientPayment.fromJson(Map<String, dynamic> json) {
    return ClientPayment(
      id: json['id'],
      clientId: json['client_id'] ?? json['clientId'], // Handle both formats
      amount: (json['amount'] as num).toDouble(),
      imageUrl: json['image_url'] ?? json['imageUrl'], // Handle both formats
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId, // Use snake_case for server compatibility
      'amount': amount,
      'image_url': imageUrl, // Use snake_case for server compatibility
      'date': date.toIso8601String(),
      'status': status,
    };
  }
}
