import 'package:get/get.dart';
import 'package:woosh/models/product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;
}

class CartController extends GetxController {
  final RxList<CartItem> _items = <CartItem>[].obs;
  
  List<CartItem> get items => _items;
  
  double get total => _items.fold(
        0,
        (sum, item) => sum + item.total,
      );

  void addToCart(Product product, int quantity) {
    print('Adding to cart: ${product.name}, ID: ${product.id}, Quantity: $quantity');
    print('Current cart items: ${_items.length}');
    
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );
    print('Existing index: $existingIndex');

    if (existingIndex >= 0) {
      print('Updating existing item');
      _items[existingIndex].quantity += quantity;
      _items.refresh();
    } else {
      print('Adding new item');
      _items.add(CartItem(product: product, quantity: quantity));
    }
    
    print('Cart items after adding: ${_items.length}');
    for (var item in _items) {
      print('- ${item.product.name}: ${item.quantity}');
    }
  }

  void removeFromCart(int index) {
    _items.removeAt(index);
  }

  void updateQuantity(int index, int quantity) {
    if (quantity > 0) {
      _items[index].quantity = quantity;
      _items.refresh();
    }
  }

  void clearCart() {
    _items.clear();
  }
}
