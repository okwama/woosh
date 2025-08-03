import 'package:get/get.dart';
import 'package:woosh/models/hive/client_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/clients/client_model.dart';

class UpliftCartItem {
  final Product product;
  final int quantity;
  final double unitPrice;

  UpliftCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}

class UpliftCartController extends GetxController {
  final RxList<UpliftCartItem> items = <UpliftCartItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  ClientModel? currentClient;

  void setClient(ClientModel client) {
    currentClient = client;
  }

  void addItem(Product product, int quantity, double unitPrice) {
    final existingItemIndex = items.indexWhere(
      (item) => item.product.id == product.id && item.unitPrice == unitPrice,
    );

    if (existingItemIndex >= 0) {
      // Update existing item
      final existingItem = items[existingItemIndex];
      items[existingItemIndex] = UpliftCartItem(
        product: product,
        quantity: existingItem.quantity + quantity,
        unitPrice: unitPrice,
      );
    } else {
      // Add new item
      items.add(
        UpliftCartItem(
          product: product,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      );
    }
  }

  void updateItemQuantity(UpliftCartItem item, int newQuantity) {
    final index = items.indexOf(item);
    if (index >= 0) {
      items[index] = UpliftCartItem(
        product: item.product,
        quantity: newQuantity,
        unitPrice: item.unitPrice,
      );
    }
  }

  void removeItem(UpliftCartItem item) {
    items.remove(item);
  }

  void clear() {
    items.clear();
    errorMessage.value = '';
  }

  double get totalAmount {
    return items.fold(0.0, (sum, item) => sum + item.total);
  }

  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  int get totalPieces {
    return items.fold(0, (sum, item) {
      final unitOfMeasure = item.product.unitOfMeasure;
      return sum +
          (unitOfMeasure != null
              ? item.quantity * (int.tryParse(unitOfMeasure) ?? 1)
              : item.quantity);
    });
  }

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  void clearCart() {}
}
