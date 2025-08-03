import 'package:get/get.dart';
import 'product_model.dart';

class CartItem {
  final Product product;
  final RxInt quantity;
  final RxInt? storeId;

  CartItem({
    required this.product,
    required int quantity,
    int? storeId,
  })  : quantity = quantity.obs,
        storeId = storeId?.obs;

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'quantity': quantity.value,
      if (storeId?.value != null) 'storeId': storeId!.value,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json, Product product) {
    return CartItem(
      product: product,
      quantity: json['quantity'] != null
          ? int.tryParse(json['quantity'].toString()) ?? 0
          : 0,
      storeId: json['storeId'] != null
          ? int.tryParse(json['storeId'].toString())
          : null,
    );
  }
}
