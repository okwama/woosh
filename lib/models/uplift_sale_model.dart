import 'package:get/get.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/outlet_model.dart';
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
      id: json['id'] as int,
      upliftSaleId: json['upliftSaleId'] as int,
      productId: json['productId'] as int,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      product: json['product'] != null
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
      id: json['id'] as int,
      clientId: json['clientId'] as int,
      userId: json['userId'] as int,
      status: json['status'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      items: (json['items'] as List<dynamic>)
          .map((item) => UpliftSaleItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      client: json['client'] != null
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
}
