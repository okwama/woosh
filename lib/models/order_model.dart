class Order {
  final int id;
  final String product;
  final int quantity;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.product,
    required this.quantity,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      product: json['product'],
      quantity: json['quantity'],
      userId: json['userId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product,
      'quantity': quantity,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}