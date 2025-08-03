import 'package:get/get.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/services/hive/cart_hive_service.dart';

class CartController extends GetxController {
  final CartHiveService _cartHiveService = CartHiveService();
  final RxList<OrderItem> items = <OrderItem>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCartItems();
  }

  Future<void> loadCartItems() async {
    try {
      isLoading.value = true;
      await _cartHiveService.init();
      items.value = _cartHiveService.getCartItems();
    } catch (e) {
      print('Error loading cart items: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addItem(OrderItem item) async {
    try {
      // Check if item with same product and unit price exists
      final existingItemIndex = items.indexWhere((i) =>
          i.productId == item.productId && i.unitPrice == item.unitPrice);

      if (existingItemIndex != -1) {
        // Update quantity if item exists
        final existingItem = items[existingItemIndex];
        final updatedItem = existingItem.copyWith(
            quantity: existingItem.quantity + item.quantity);
        items[existingItemIndex] = updatedItem;
        await _cartHiveService.updateItem(existingItemIndex, updatedItem);
      } else {
        // Add new item
        items.add(item);
        await _cartHiveService.addItem(item);
      }
    } catch (e) {
      print('Error adding item to cart: $e');
      rethrow;
    }
  }

  Future<void> removeItem(OrderItem item) async {
    try {
      final index = items.indexWhere((i) =>
          i.productId == item.productId && i.unitPrice == item.unitPrice);
      if (index != -1) {
        items.removeAt(index);
        await _cartHiveService.removeItem(index);
      }
    } catch (e) {
      print('Error removing item from cart: $e');
      rethrow;
    }
  }

  Future<void> updateItemQuantity(OrderItem item, int quantity) async {
    try {
      final index = items.indexWhere((i) =>
          i.productId == item.productId && i.unitPrice == item.unitPrice);
      if (index != -1) {
        final updatedItem = item.copyWith(quantity: quantity);
        items[index] = updatedItem;
        await _cartHiveService.updateItem(index, updatedItem);
      }
    } catch (e) {
      print('Error updating item quantity: $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      items.clear();
      await _cartHiveService.clearCart();
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  int get totalItems => items.length;

  double get totalAmount {
    return items.fold(0.0, (sum, item) {
      // Use the unit price directly from the order item
      double price = item.unitPrice;
      return sum + (price * item.quantity);
    });
  }
}
