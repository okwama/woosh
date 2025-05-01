import 'package:get/get.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/outlet_model.dart';

class UpliftCartItem {
  final Product product;
  final int quantity;
  final int? priceOptionId;
  final double unitPrice;

  UpliftCartItem({
    required this.product,
    required this.quantity,
    this.priceOptionId,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}

class UpliftCartController extends GetxController {
  final RxList<UpliftCartItem> items = <UpliftCartItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  Outlet? currentOutlet;

  void setOutlet(Outlet outlet) {
    currentOutlet = outlet;
  }

  void addItem(Product product, int quantity, {int? priceOptionId}) {
    final existingItemIndex = items.indexWhere(
      (item) =>
          item.product.id == product.id && item.priceOptionId == priceOptionId,
    );

    if (existingItemIndex >= 0) {
      // Update existing item
      final existingItem = items[existingItemIndex];
      items[existingItemIndex] = UpliftCartItem(
        product: product,
        quantity: existingItem.quantity + quantity,
        priceOptionId: priceOptionId,
        unitPrice: existingItem.unitPrice,
      );
    } else {
      // Add new item
      final unitPrice = priceOptionId != null
          ? product.priceOptions
              .firstWhere((po) => po.id == priceOptionId)
              .value
              .toDouble()
          : 0.0;
      items.add(
        UpliftCartItem(
          product: product,
          quantity: quantity,
          priceOptionId: priceOptionId,
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
        priceOptionId: item.priceOptionId,
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
      final packSize = item.product.packSize;
      return sum +
          (packSize != null ? item.quantity * packSize : item.quantity);
    });
  }

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;
}
