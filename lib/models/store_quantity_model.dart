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
      id: json['id'],
      quantity: json['quantity'],
      storeId: json['storeId'],
      productId: json['productId'],
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
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
