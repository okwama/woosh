import 'package:get/get.dart';
import 'product_model.dart';

class CartItem {
  final Product product;
  final RxInt quantity;

  CartItem({
    required this.product,
    required int quantity,
  }) : quantity = quantity.obs;

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'quantity': quantity.value,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json, Product product) {
    return CartItem(
      product: product,
      quantity: json['quantity'] as int,
    );
  }
}
