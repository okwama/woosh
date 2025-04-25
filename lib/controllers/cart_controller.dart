import 'package:get/get.dart';
import 'package:woosh/models/product_model.dart';

class CartItem {
  final Product product;
  RxInt quantity;

  CartItem({required this.product, required int quantity})
      : quantity = quantity.obs;
}

class CartController extends GetxController {
  final RxList<CartItem> _items = <CartItem>[].obs;
  final isLoading = false.obs;
  final error = ''.obs;

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  void addToCart(Product product, int quantity) {
    try {
      error.value = ''; // Clear any previous errors
      final existingIndex = _items.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (existingIndex >= 0) {
        // Update existing item quantity
        _items[existingIndex].quantity.value += quantity;
        _items.refresh(); // Ensure the list updates
      } else {
        // Add new item
        _items.add(CartItem(product: product, quantity: quantity));
      }
    } catch (e) {
      error.value = 'Error adding to cart: $e';
      print(error.value);
      rethrow; // Rethrow to handle in UI
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
    }
  }

  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < _items.length && quantity > 0) {
      _items[index].quantity.value = quantity;
      _items.refresh(); // Ensure the list updates
    }
  }

  void clearCart() {
    _items.clear();
  }
}
