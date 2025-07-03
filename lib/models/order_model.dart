import 'package:glamour_queen/models/orderitem_model.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/models/user_model.dart';
import 'package:glamour_queen/models/client_model.dart';
import 'package:glamour_queen/models/price_option_model.dart';

enum OrderStatus { PENDING, COMPLETED, CANCELLED }

class Order {
  final int id;
  final int quantity;
  final SalesRep user;
  final Client client;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> orderItems;
  final double? _totalAmount; // Store the total amount from the database

  Order({
    required this.id,
    required this.quantity,
    required this.user,
    required this.client,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    required this.orderItems,
    double? totalAmount,
  }) : _totalAmount = totalAmount;

  // Get total amount from database or calculate from order items if not available
  double get totalAmount {
    // If we have a total amount from the database, use it
    if (_totalAmount != null) {
      return _totalAmount;
    }

    // Otherwise calculate from order items
    return orderItems.fold(0.0, (total, item) {
      if (item.product == null || item.priceOptionId == null) return total;

      // Find the matching price option
      final priceOption = item.product!.priceOptions.firstWhere(
        (opt) => opt.id == item.priceOptionId,
        orElse: () => PriceOption(
            id: 0,
            option: '',
            value: null,
            value_tzs: null,
            value_ngn: null,
            categoryId: 0),
      );

      // Calculate the item price
      return total + ((priceOption.value ?? 0) * item.quantity);
    });
  }

  // Default status is PENDING
  OrderStatus get status => OrderStatus.PENDING;

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      // Debug the incoming JSON structure
      print('Parsing Order JSON: ${json.keys}');

      // Safely extract user/client data with null checks
      Map<String, dynamic>? userData = json['user'];
      Map<String, dynamic>? clientData = json['client'];

      if (userData == null) {
        print('Warning: user data is null in Order JSON');
      }

      if (clientData == null) {
        print('Warning: client data is null in Order JSON');
      }

      // Handle dates safely with timezone consideration
      DateTime createdAt;
      try {
        if (json['createdAt'] != null) {
          // Try to parse with timezone aware handling
          final String dateStr = json['createdAt'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            // ISO format with timezone info
            createdAt = DateTime.parse(dateStr).toLocal();
          } else {
            // Plain date string
            createdAt = DateTime.parse(dateStr);
          }
        } else {
          createdAt = DateTime.now();
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
        print('Original value: ${json['createdAt']}');
        createdAt = DateTime.now();
      }

      DateTime updatedAt;
      try {
        if (json['updatedAt'] != null) {
          // Try to parse with timezone aware handling
          final String dateStr = json['updatedAt'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            // ISO format with timezone info
            updatedAt = DateTime.parse(dateStr).toLocal();
          } else {
            // Plain date string
            updatedAt = DateTime.parse(dateStr);
          }
        } else {
          updatedAt = DateTime.now();
        }
      } catch (e) {
        print('Error parsing updatedAt: $e');
        print('Original value: ${json['updatedAt']}');
        updatedAt = DateTime.now();
      }

      // Parse totalAmount from JSON if available
      double? totalAmount;
      if (json['totalAmount'] != null) {
        try {
          totalAmount = double.parse(json['totalAmount'].toString());
        } catch (e) {
          print('Error parsing totalAmount: $e');
          print('Original value: ${json['totalAmount']}');
        }
      }

      return Order(
        id: json['id'] as int,
        quantity: json['quantity'] ?? 0,
        totalAmount: totalAmount,
        imageUrl: json['imageUrl'] as String?,
        // Create user and client objects with safe fallbacks
        user: userData != null
            ? SalesRep.fromJson(userData)
            : SalesRep.fromJson(
                {'id': 0, 'name': 'Unknown', 'phoneNumber': ''}),
        client: clientData != null
            ? Client.fromJson(clientData)
            : Client.fromJson({'id': 0, 'name': 'Unknown Client'}),
        createdAt: createdAt,
        updatedAt: updatedAt,
        orderItems: _parseOrderItems(json),
      );
    } catch (e) {
      print('Error parsing Order from JSON: $e');
      print('Received JSON: $json');
      rethrow;
    }
  }

  // Helper method to safely parse order items
  static List<OrderItem> _parseOrderItems(Map<String, dynamic> json) {
    try {
      final items = json['orderItems'];
      if (items == null) {
        print('orderItems is null in Order JSON');
        return [];
      }

      if (items is! List) {
        print('orderItems is not a List in Order JSON');
        return [];
      }

      return items
          .map((item) =>
              item is Map<String, dynamic> ? OrderItem.fromJson(item) : null)
          .where((item) => item != null)
          .cast<OrderItem>()
          .toList();
    } catch (e) {
      print('Error parsing order items: $e');
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'user': user.toJson(),
      'client': client.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
      'imageUrl': imageUrl,
    };
  }
}

