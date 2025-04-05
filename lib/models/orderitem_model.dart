import 'product_model.dart';

class OrderItem {
  final int? id;
  final int productId;
  final int quantity;
  final Product? product; // Keep product optional but properly typed

  OrderItem({
    this.id,
    required this.productId,
    required this.quantity,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      productId: json['productId'],
      quantity: json['quantity'],
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'quantity': quantity,
    };
  }
}
