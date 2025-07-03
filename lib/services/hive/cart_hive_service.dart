import 'package:hive/hive.dart';
import 'package:glamour_queen/models/hive/cart_item_model.dart';
import 'package:glamour_queen/models/orderitem_model.dart';

class CartHiveService {
  static const String _boxName = 'cartBox';
  late Box<CartItemModel> _cartBox;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _cartBox = await Hive.openBox<CartItemModel>(_boxName);
    } else {
      _cartBox = Hive.box<CartItemModel>(_boxName);
    }
  }

  Future<void> saveCartItems(List<OrderItem> items) async {
    await _cartBox.clear();
    for (var item in items) {
      await _cartBox.add(CartItemModel.fromOrderItem(item));
    }
  }

  List<OrderItem> getCartItems() {
    return _cartBox.values.map((item) => item.toOrderItem()).toList();
  }

  Future<void> clearCart() async {
    await _cartBox.clear();
  }

  Future<void> addItem(OrderItem item) async {
    await _cartBox.add(CartItemModel.fromOrderItem(item));
  }

  Future<void> removeItem(int index) async {
    await _cartBox.deleteAt(index);
  }

  Future<void> updateItem(int index, OrderItem item) async {
    await _cartBox.putAt(index, CartItemModel.fromOrderItem(item));
  }

  bool get isEmpty => _cartBox.isEmpty;
  int get length => _cartBox.length;
}

