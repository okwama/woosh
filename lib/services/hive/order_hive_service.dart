import 'package:hive/hive.dart';
import '../../models/hive/order_model.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';



// Ensure the adapter is registered
void ensureOrderHiveAdapterRegistered() {
  try {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(OrderModelAdapter());
      debugPrint('OrderModelAdapter registered manually');
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OrderItemModelAdapter());
      debugPrint('OrderItemModelAdapter registered manually');
    }
  } catch (e) {
    debugPrint('Error registering Order adapters: $e');
  }
}

class OrderHiveService {
  static const String _boxName = 'orders';
  static const String _timestampBoxName = 'timestamps';
  
  Box<OrderModel>? _orderBox;
  Box? _timestampBox;
  
  // Flag to track initialization status
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    // If already initializing, wait for that to complete
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    // If already initialized, return immediately
    if (_isInitialized) {
      return;
    }
    
    // Create a completer to track initialization
    _initCompleter = Completer<void>();
    
    try {
      // Ensure adapter is registered
      ensureOrderHiveAdapterRegistered();
      
      debugPrint('OrderHiveService: Starting initialization');
      
      // Open the orders box if not already open
      if (!Hive.isBoxOpen(_boxName)) {
        debugPrint('OrderHiveService: Opening orders box');
        _orderBox = await Hive.openBox<OrderModel>(_boxName);
      } else {
        debugPrint('OrderHiveService: Orders box already open');
        _orderBox = Hive.box<OrderModel>(_boxName);
      }
      
      // Open the timestamps box if not already open
      if (!Hive.isBoxOpen(_timestampBoxName)) {
        debugPrint('OrderHiveService: Opening timestamps box');
        _timestampBox = await Hive.openBox(_timestampBoxName);
      } else {
        debugPrint('OrderHiveService: Timestamps box already open');
        _timestampBox = Hive.box(_timestampBoxName);
      }
      
      _isInitialized = true;
      debugPrint('OrderHiveService: Initialization complete');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('OrderHiveService: Error during initialization: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }
  
  // Helper method to ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      debugPrint('OrderHiveService: Not initialized, initializing now');
      await init();
    }
  }

  Future<void> saveOrder(OrderModel order) async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot save order, box is null');
      return;
    }
    
    try {
      await _orderBox!.put(order.id, order);
      debugPrint('OrderHiveService: Saved order ${order.id}');
    } catch (e) {
      debugPrint('OrderHiveService: Error saving order: $e');
      rethrow;
    }
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot save orders, box is null');
      return;
    }
    
    try {
      final Map<int, OrderModel> orderMap = {
        for (var order in orders) order.id: order
      };
      await _orderBox!.putAll(orderMap);
      debugPrint('OrderHiveService: Saved ${orders.length} orders');
    } catch (e) {
      debugPrint('OrderHiveService: Error saving orders: $e');
      rethrow;
    }
  }

  Future<OrderModel?> getOrder(int id) async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot get order, box is null');
      return null;
    }
    
    try {
      return _orderBox!.get(id);
    } catch (e) {
      debugPrint('OrderHiveService: Error getting order: $e');
      return null;
    }
  }

  Future<List<OrderModel>> getAllOrders() async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot get all orders, box is null');
      return [];
    }
    
    try {
      return _orderBox!.values.toList();
    } catch (e) {
      debugPrint('OrderHiveService: Error getting all orders: $e');
      return [];
    }
  }

  Future<List<OrderModel>> getOrdersByClient(int clientId) async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot get orders by client, box is null');
      return [];
    }
    
    try {
      return _orderBox!.values
          .where((order) => order.clientId == clientId)
          .toList();
    } catch (e) {
      debugPrint('OrderHiveService: Error getting orders by client: $e');
      return [];
    }
  }

  Future<void> deleteOrder(int id) async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot delete order, box is null');
      return;
    }
    
    try {
      await _orderBox!.delete(id);
      debugPrint('OrderHiveService: Deleted order $id');
    } catch (e) {
      debugPrint('OrderHiveService: Error deleting order: $e');
      rethrow;
    }
  }

  Future<void> clearAllOrders() async {
    await _ensureInitialized();
    if (_orderBox == null) {
      debugPrint('OrderHiveService: Cannot clear orders, box is null');
      return;
    }
    
    try {
      await _orderBox!.clear();
      debugPrint('OrderHiveService: Cleared all orders');
    } catch (e) {
      debugPrint('OrderHiveService: Error clearing orders: $e');
      rethrow;
    }
  }
  
  // Get the timestamp of the last update
  Future<DateTime?> getLastUpdateTime() async {
    await _ensureInitialized();
    if (_timestampBox == null) {
      debugPrint('OrderHiveService: Cannot get last update time, timestamps box is null');
      return null;
    }
    
    try {
      final timestamp = _timestampBox!.get('orders_last_update');
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      debugPrint('OrderHiveService: Error getting last update time: $e');
      return null;
    }
  }
  
  // Set the timestamp of the last update
  Future<void> setLastUpdateTime(DateTime timestamp) async {
    await _ensureInitialized();
    if (_timestampBox == null) {
      debugPrint('OrderHiveService: Cannot set last update time, timestamps box is null');
      return;
    }
    
    try {
      await _timestampBox!.put('orders_last_update', timestamp.millisecondsSinceEpoch);
      debugPrint('OrderHiveService: Updated last update timestamp');
    } catch (e) {
      debugPrint('OrderHiveService: Error setting last update time: $e');
      rethrow;
    }
  }
}
