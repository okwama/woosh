import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/outlet_model.dart';

class Order {
  final int id;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Product product;
  final Outlet outlet;

  Order({
    required this.id,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
    required this.product,
    required this.outlet,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      quantity: json['quantity'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      product: Product.fromJson(json['product']),
      outlet: Outlet.fromJson(json['outlet']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'product': product.toJson(),
      'outlet': outlet.toJson(),
    };
  }
}
