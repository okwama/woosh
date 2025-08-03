import 'store_model.dart';

class StoreQuantity {
  final int id;
  final int quantity;
  final int storeId;
  final int productId;
  final Store? store;

  StoreQuantity({
    required this.id,
    required this.quantity,
    required this.storeId,
    required this.productId,
    this.store,
  });

  factory StoreQuantity.fromJson(Map<String, dynamic> json) {
    return StoreQuantity(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      quantity: json['quantity'] != null
          ? int.tryParse(json['quantity'].toString()) ?? 0
          : 0,
      storeId: json['store_id'] != null
          ? int.tryParse(json['store_id'].toString()) ?? 0
          : json['storeId'] != null
              ? int.tryParse(json['storeId'].toString()) ?? 0
              : 0,
      productId: json['product_id'] != null
          ? int.tryParse(json['product_id'].toString()) ?? 0
          : json['productId'] != null
              ? int.tryParse(json['productId'].toString()) ?? 0
              : 0,
      store: json['stores'] != null
          ? Store.fromJson(json['stores'])
          : json['store'] != null
              ? Store.fromJson(json['store'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'storeId': storeId,
      'productId': productId,
      if (store != null) 'store': store!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreQuantity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
