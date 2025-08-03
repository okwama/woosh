import 'package:get/get.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:dio/dio.dart';
import 'package:woosh/services/api_service.dart';

class UpliftSaleItem {
  final int id;
  final int upliftSaleId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double total;
  final DateTime createdAt;
  final Product? product;

  UpliftSaleItem({
    required this.id,
    required this.upliftSaleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
    this.product,
  });

  factory UpliftSaleItem.fromJson(Map<String, dynamic> json) {
    return UpliftSaleItem(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      upliftSaleId: json['upliftSaleId'] != null
          ? int.tryParse(json['upliftSaleId'].toString()) ?? 0
          : 0,
      productId: json['productId'] != null
          ? int.tryParse(json['productId'].toString()) ?? 0
          : 0,
      quantity: json['quantity'] != null
          ? int.tryParse(json['quantity'].toString()) ?? 0
          : 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      product: json['products'] != null
          ? Product.fromJson(json['products'] as Map<String, dynamic>)
          : json['product'] != null
              ? Product.fromJson(json['product'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }
}

class UpliftSale {
  final int id;
  final int clientId;
  final int userId;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UpliftSaleItem> items;
  final Client? client;

  UpliftSale({
    required this.id,
    required this.clientId,
    required this.userId,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.client,
  });

  factory UpliftSale.fromJson(Map<String, dynamic> json) {
    return UpliftSale(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      clientId: json['clientId'] != null
          ? int.tryParse(json['clientId'].toString()) ?? 0
          : 0,
      userId: json['userId'] != null
          ? int.tryParse(json['userId'].toString()) ?? 0
          : 0,
      status: json['status'] as String? ?? 'pending',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDateTime(json['createdAt']?.toString() ?? ''),
      updatedAt: _parseDateTime(json['updatedAt']?.toString() ?? ''),
      items: (json['UpliftSaleItem'] as List<dynamic>?)
              ?.map((item) =>
                  UpliftSaleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      client: json['Clients'] != null
          ? Client.fromJson(json['Clients'] as Map<String, dynamic>)
          : json['client'] != null
              ? Client.fromJson(json['client'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  static DateTime _parseDateTime(String dateString) {
    // Handle invalid dates like "0000-00-00 00:00:00.000"
    if (dateString.contains('0000-00-00') || dateString.isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(dateString) ?? DateTime.now();
  }
}
