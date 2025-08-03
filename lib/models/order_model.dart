import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/user_model.dart';
import 'package:woosh/models/clients/client_model.dart';

enum OrderStatus {
  DRAFT,
  CONFIRMED,
  SHIPPED,
  DELIVERED,
  CANCELLED,
  IN_PAYMENT,
  PAID
}

class Order {
  final int id;
  final String soNumber;
  final int clientId;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final double? subtotal;
  final double? taxAmount;
  final double? totalAmount;
  final double netPrice;
  final String? notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int riderId;
  final DateTime? assignedAt;
  final OrderStatus status;
  final int myStatus;
  final SalesRep user;
  final Client client;
  final List<OrderItem> orderItems;

  Order({
    required this.id,
    required this.soNumber,
    required this.clientId,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.subtotal,
    this.taxAmount,
    this.totalAmount,
    required this.netPrice,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.riderId,
    this.assignedAt,
    required this.status,
    required this.myStatus,
    required this.user,
    required this.client,
    required this.orderItems,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      // Debug the incoming JSON structure
      print('Parsing Order JSON: ${json.keys}');

      // Safely extract user/client data with null checks
      Map<String, dynamic>? userData = json['user'];
      Map<String, dynamic>? clientData =
          json['Clients'] ?? json['client']; // Try both 'Clients' and 'client'

      if (userData == null) {
        print('Warning: user data is null in Order JSON');
      }

      if (clientData == null) {
        print('Warning: client data is null in Order JSON');
        print('Available keys in JSON: ${json.keys}');
      }

      // Parse status
      OrderStatus status;
      try {
        status = OrderStatus.values.firstWhere(
          (e) =>
              e.name.toLowerCase() ==
              (json['status'] ?? 'draft').toString().toLowerCase(),
          orElse: () => OrderStatus.DRAFT,
        );
      } catch (e) {
        print('Error parsing status: $e');
        status = OrderStatus.DRAFT;
      }

      // Handle dates safely with timezone consideration
      DateTime orderDate;
      try {
        if (json['order_date'] != null) {
          final String dateStr = json['order_date'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            orderDate = DateTime.parse(dateStr).toLocal();
          } else {
            orderDate = DateTime.parse(dateStr);
          }
        } else {
          orderDate = DateTime.now();
        }
      } catch (e) {
        print('Error parsing order_date: $e');
        orderDate = DateTime.now();
      }

      DateTime createdAt;
      try {
        if (json['created_at'] != null) {
          final String dateStr = json['created_at'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            createdAt = DateTime.parse(dateStr).toLocal();
          } else {
            createdAt = DateTime.parse(dateStr);
          }
        } else {
          createdAt = DateTime.now();
        }
      } catch (e) {
        print('Error parsing created_at: $e');
        createdAt = DateTime.now();
      }

      DateTime updatedAt;
      try {
        if (json['updated_at'] != null) {
          final String dateStr = json['updated_at'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            updatedAt = DateTime.parse(dateStr).toLocal();
          } else {
            updatedAt = DateTime.parse(dateStr);
          }
        } else {
          updatedAt = DateTime.now();
        }
      } catch (e) {
        print('Error parsing updated_at: $e');
        updatedAt = DateTime.now();
      }

      DateTime? expectedDeliveryDate;
      try {
        if (json['expected_delivery_date'] != null) {
          final String dateStr = json['expected_delivery_date'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            expectedDeliveryDate = DateTime.parse(dateStr).toLocal();
          } else {
            expectedDeliveryDate = DateTime.parse(dateStr);
          }
        }
      } catch (e) {
        print('Error parsing expected_delivery_date: $e');
        expectedDeliveryDate = null;
      }

      DateTime? assignedAt;
      try {
        if (json['assigned_at'] != null) {
          final String dateStr = json['assigned_at'].toString();
          if (dateStr.contains('T') || dateStr.contains('Z')) {
            assignedAt = DateTime.parse(dateStr).toLocal();
          } else {
            assignedAt = DateTime.parse(dateStr);
          }
        }
      } catch (e) {
        print('Error parsing assigned_at: $e');
        assignedAt = null;
      }

      return Order(
        id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
        soNumber: json['soNumber'] ?? '',
        clientId: json['clientId'] ?? 0,
        orderDate: orderDate,
        expectedDeliveryDate: expectedDeliveryDate,
        subtotal: json['subtotal'] != null
            ? double.tryParse(json['subtotal'].toString())
            : null,
        taxAmount: json['taxAmount'] != null
            ? double.tryParse(json['taxAmount'].toString())
            : null,
        totalAmount: json['totalAmount'] != null
            ? double.tryParse(json['totalAmount'].toString())
            : null,
        netPrice: json['netPrice'] != null
            ? double.tryParse(json['netPrice'].toString()) ?? 0.0
            : 0.0,
        notes: json['notes'],
        createdBy: json['created_by'] ?? 0,
        createdAt: createdAt,
        updatedAt: updatedAt,
        riderId: json['rider_id'] ?? 0,
        assignedAt: assignedAt,
        status: status,
        myStatus: json['my_status'] ?? 0,
        // Create user and client objects with safe fallbacks
        user: userData != null
            ? SalesRep.fromJson(userData)
            : SalesRep.fromJson(
                {'id': 0, 'name': 'Unknown', 'phoneNumber': ''}),
        client: clientData != null
            ? Client.fromJson(clientData)
            : Client.fromJson({'id': 0, 'name': 'Unknown Client'}),
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
      final items = json['sales_order_items'] ?? json['orderItems'];
      if (items == null) {
        print('sales_order_items is null in Order JSON');
        return [];
      }

      if (items is! List) {
        print('sales_order_items is not a List in Order JSON');
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
      'so_number': soNumber,
      'client_id': clientId,
      'order_date': orderDate.toIso8601String(),
      if (expectedDeliveryDate != null)
        'expected_delivery_date': expectedDeliveryDate!.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'net_price': netPrice,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'rider_id': riderId,
      if (assignedAt != null) 'assigned_at': assignedAt!.toIso8601String(),
      'status': status.name.toLowerCase(),
      'my_status': myStatus,
      'user': user.toJson(),
      'client': client.toJson(),
      'sales_order_items': orderItems.map((item) => item.toJson()).toList(),
    };
  }
}
