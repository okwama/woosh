import 'package:hive/hive.dart';
import '../../models/hive/order_model.dart';



class OrderHiveService {
  static const String _boxName = 'orders';
  late Box<OrderModel> _orderBox;

  Future<void> init() async {
    _orderBox = await Hive.openBox<OrderModel>(_boxName);
  }

  Future<void> saveOrder(OrderModel order) async {
    await _orderBox.put(order.id, order);
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    final Map<int, OrderModel> orderMap = {
      for (var order in orders) order.id: order
    };
    await _orderBox.putAll(orderMap);
  }

  OrderModel? getOrder(int id) {
    return _orderBox.get(id);
  }

  List<OrderModel> getAllOrders() {
    return _orderBox.values.toList();
  }

  List<OrderModel> getOrdersByClient(int clientId) {
    return _orderBox.values
        .where((order) => order.clientId == clientId)
        .toList();
  }

  Future<void> deleteOrder(int id) async {
    await _orderBox.delete(id);
  }

  Future<void> clearAllOrders() async {
    await _orderBox.clear();
  }
}
