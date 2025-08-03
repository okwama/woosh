import 'package:hive/hive.dart';

part 'order_model.g.dart';

@HiveType(typeId: 0)
class OrderModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int clientId;

  @HiveField(2)
  final String orderNumber;

  @HiveField(3)
  final DateTime orderDate;

  @HiveField(4)
  final double totalAmount;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.orderNumber,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      clientId: json['clientId'],
      orderNumber: json['orderNumber'],
      orderDate: DateTime.parse(json['orderDate']),
      totalAmount: json['totalAmount'].toDouble(),
      status: json['status'],
      items: (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'orderNumber': orderNumber,
      'orderDate': orderDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 1)
class OrderItemModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int productId;

  @HiveField(2)
  final String productName;

  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final double unitPrice;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? 'Unknown Product',
      quantity: json['quantity'],
      unitPrice: json['unit_price']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}
