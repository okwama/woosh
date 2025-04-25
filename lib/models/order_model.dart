import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/user_model.dart';
import 'package:woosh/models/client_model.dart';

enum OrderStatus { PENDING, COMPLETED, CANCELLED }

class Order {
  final int id;
  final int quantity;
  final SalesRep user;
  final Client client;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> orderItems;

  Order({
    required this.id,
    required this.quantity,
    required this.user,
    required this.client,
    required this.createdAt,
    required this.updatedAt,
    required this.orderItems,
  });

  // Calculate total amount based on order items
  double get totalAmount {
    return orderItems.fold(0, (total, item) => total);
  }

  // Default status is PENDING
  OrderStatus get status => OrderStatus.PENDING;

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: json['id'] as int,
        quantity: json['quantity'] ?? 0,
        user: SalesRep.fromJson(json['user']),
        client: Client.fromJson(json['client']),
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
      'client': client.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
    };
  }
}
