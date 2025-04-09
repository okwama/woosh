import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/user_model.dart';

class Order {
  final int id;
  final int quantity;
  final User user;
  final Outlet outlet;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> orderItems;

  Order({
    required this.id,
    required this.quantity,
    required this.user,
    required this.outlet,
    required this.createdAt,
    required this.updatedAt,
    required this.orderItems,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: json['id'] as int,
        quantity: json['quantity'] ?? 0,
        user: User.fromJson(json['user']),
        outlet: Outlet.fromJson(json['outlet']),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        orderItems: (json['orderItems'] as List?)
                ?.map((item) => OrderItem.fromJson(item))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing Order from JSON: $e');
      print('Received JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'user': user.toJson(),
      'outlet': outlet.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
    };
  }
}
