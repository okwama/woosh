class Order {
  final int id;
  final int productId;
  final int quantity;
  final int userId;
  final int outletId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.userId,
    required this.outletId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      productId: json['productId'],
      quantity: json['quantity'],
      userId: json['userId'],
      outletId: json['outletId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'userId': userId,
      'outletId': outletId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
