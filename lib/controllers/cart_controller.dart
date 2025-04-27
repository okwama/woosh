import 'package:get/get.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/price_option_model.dart';

class CartController extends GetxController {
  final RxList<OrderItem> items = <OrderItem>[].obs;

  void addItem(OrderItem item) {
    // Check if item with same product and price option exists
    final existingItemIndex = items.indexWhere((i) =>
        i.productId == item.productId && i.priceOptionId == item.priceOptionId);

    if (existingItemIndex != -1) {
      // Update quantity if item exists
      final existingItem = items[existingItemIndex];
      items[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity);
    } else {
      // Add new item
      items.add(item);
    }
  }

  void removeItem(OrderItem item) {
    items.removeWhere((i) =>
        i.productId == item.productId && i.priceOptionId == item.priceOptionId);
  }

  void updateItemQuantity(OrderItem item, int quantity) {
    final index = items.indexWhere((i) =>
        i.productId == item.productId && i.priceOptionId == item.priceOptionId);
    if (index != -1) {
      items[index] = item.copyWith(quantity: quantity);
    }
  }

  void clear() {
    items.clear();
  }

  int get totalItems => items.length;

  double get totalAmount {
    return items.fold(0, (sum, item) {
      final priceOption = item.product?.priceOptions
          .firstWhereOrNull((po) => po.id == item.priceOptionId);
      return sum + (priceOption?.value ?? 0) * item.quantity;
    });
  }
}
