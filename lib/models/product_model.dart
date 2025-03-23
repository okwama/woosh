import 'package:whoosh/models/outlet_model.dart';

class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int currentStock;
  final int reorderPoint;
  final int orderQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int outletId;
  final Outlet? outlet;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currentStock,
    required this.reorderPoint,
    required this.orderQuantity,
    required this.createdAt,
    required this.updatedAt,
    required this.outletId,
    this.outlet,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      currentStock: json['currentStock'],
      reorderPoint: json['reorderPoint'],
      orderQuantity: json['orderQuantity'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      outletId: json['outletId'],
      outlet: json['outlet'] != null ? Outlet.fromJson(json['outlet']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currentStock': currentStock,
      'reorderPoint': reorderPoint,
      'orderQuantity': orderQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'outletId': outletId,
      'outlet': outlet?.toJson(),
    };
  }
}
