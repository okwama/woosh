import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/order_model.dart';
import 'package:get_storage/get_storage.dart';

class OrderStatusTrackingService extends GetxService {
  static OrderStatusTrackingService get instance => Get.find<OrderStatusTrackingService>();

  final GetStorage _storage = GetStorage();
  Timer? _statusUpdateTimer;
  
  // Observable order status data
  final RxList<OrderStatusUpdate> _orderUpdates = <OrderStatusUpdate>[].obs;
  final RxMap<int, String> _orderStatuses = <int, String>{}.obs;
  final RxBool _isTracking = false.obs;

  // Configuration
  static const int statusCheckIntervalSeconds = 30; // Check every 30 seconds
  static const int maxStatusUpdates = 100; // Keep last 100 updates

  List<OrderStatusUpdate> get orderUpdates => _orderUpdates;
  Map<int, String> get orderStatuses => _orderStatuses;
  bool get isTracking => _isTracking.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadStoredStatusData();
    _startStatusTracking();
  }

  @override
  void onClose() {
    _statusUpdateTimer?.cancel();
    _saveStatusData();
    super.onClose();
  }

  /// Start tracking order status updates
  void _startStatusTracking() {
    _isTracking.value = true;
    
    _statusUpdateTimer = Timer.periodic(
      Duration(seconds: statusCheckIntervalSeconds),
      (_) => _checkOrderStatusUpdates(),
    );
    
    print('📊 Order status tracking started');
  }

  /// Stop tracking order status updates
  void stopStatusTracking() {
    _isTracking.value = false;
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
    
    print('📊 Order status tracking stopped');
  }

  /// Check for order status updates
  Future<void> _checkOrderStatusUpdates() async {
    try {
      // Get user's orders from the last 7 days
      final recentOrders = await _getRecentOrders();
      
      for (final order in recentOrders) {
        await _checkIndividualOrderStatus(order);
      }
      
    } catch (e) {
      print('Error checking order status updates: $e');
    }
  }

  /// Get recent orders for status tracking
  Future<List<Order>> _getRecentOrders() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: 7));
      
      return await ApiService.getOrdersInDateRange(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('Error fetching recent orders: $e');
      return [];
    }
  }

  /// Check individual order status
  Future<void> _checkIndividualOrderStatus(Order order) async {
    try {
      final currentStatus = _orderStatuses[order.id];
      final newStatus = order.status.toString();
      
      // Check if status has changed
      if (currentStatus != null && currentStatus != newStatus) {
        _recordStatusUpdate(order.id, currentStatus, newStatus);
        _sendStatusNotification(order, currentStatus, newStatus);
      }
      
      // Update stored status
      _orderStatuses[order.id] = newStatus;
      
    } catch (e) {
      print('Error checking order ${order.id} status: $e');
    }
  }

  /// Record status update
  void _recordStatusUpdate(int orderId, String oldStatus, String newStatus) {
    final update = OrderStatusUpdate(
      orderId: orderId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      timestamp: DateTime.now(),
    );
    
    _orderUpdates.add(update);
    
    // Keep only recent updates
    if (_orderUpdates.length > maxStatusUpdates) {
      _orderUpdates.removeRange(0, _orderUpdates.length - maxStatusUpdates);
    }
    
    print('📈 Order $orderId status changed: $oldStatus → $newStatus');
  }

  /// Send status notification to user
  void _sendStatusNotification(Order order, String oldStatus, String newStatus) {
    final statusInfo = _getStatusInfo(newStatus);
    
    Get.snackbar(
      'Order Update',
      'Order #${order.id} is now ${statusInfo['label']}',
      snackPosition: SnackPosition.TOP,
      backgroundColor: statusInfo['color'],
      colorText: Colors.white,
      duration: Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () => Get.toNamed('/orders/${order.id}'),
        child: Text('View', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Get status information (color, label, etc.)
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return {'label': 'Pending Review', 'color': Colors.orange};
      case 'APPROVED':
        return {'label': 'Approved', 'color': Colors.green};
      case 'REJECTED':
        return {'label': 'Rejected', 'color': Colors.red};
      case 'IN_PROGRESS':
        return {'label': 'In Progress', 'color': Colors.blue};
      case 'DELIVERED':
        return {'label': 'Delivered', 'color': Colors.purple};
      case 'CANCELLED':
        return {'label': 'Cancelled', 'color': Colors.grey};
      default:
        return {'label': status, 'color': Colors.grey};
    }
  }

  /// Get order status for specific order
  String? getOrderStatus(int orderId) {
    return _orderStatuses[orderId];
  }

  /// Get status updates for specific order
  List<OrderStatusUpdate> getOrderStatusHistory(int orderId) {
    return _orderUpdates.where((update) => update.orderId == orderId).toList();
  }

  /// Get all pending orders
  Future<List<Order>> getPendingOrders() async {
    try {
      return await ApiService.getOrdersByStatus('PENDING');
    } catch (e) {
      print('Error fetching pending orders: $e');
      return [];
    }
  }

  /// Get orders by status
  Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      return await ApiService.getOrdersByStatus(status);
    } catch (e) {
      print('Error fetching orders by status: $e');
      return [];
    }
  }

  /// Force refresh order status
  Future<void> refreshOrderStatus(int orderId) async {
    try {
      final order = await ApiService.getOrderById(orderId);
      if (order != null) {
        await _checkIndividualOrderStatus(order);
      }
    } catch (e) {
      print('Error refreshing order status: $e');
      throw Exception('Failed to refresh order status');
    }
  }

  /// Get order status summary
  Map<String, dynamic> getOrderStatusSummary() {
    final statusCounts = <String, int>{};
    
    for (final status in _orderStatuses.values) {
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    
    return {
      'totalOrders': _orderStatuses.length,
      'statusBreakdown': statusCounts,
      'recentUpdates': _orderUpdates.length,
      'lastUpdateCheck': _storage.read<String>('last_status_check'),
    };
  }

  /// Get orders needing attention (rejected, requires action)
  List<OrderStatusUpdate> getOrdersNeedingAttention() {
    return _orderUpdates.where((update) {
      final status = update.newStatus.toUpperCase();
      return status == 'REJECTED' || 
             status == 'REQUIRES_MODIFICATION' ||
             status == 'PENDING_CLARIFICATION';
    }).toList();
  }

  /// Mark order as viewed (to reduce notification noise)
  void markOrderAsViewed(int orderId) {
    final viewedOrders = _storage.read<List>('viewed_order_updates') ?? [];
    if (!viewedOrders.contains(orderId)) {
      viewedOrders.add(orderId);
      _storage.write('viewed_order_updates', viewedOrders);
    }
  }

  /// Check if order update was viewed
  bool isOrderUpdateViewed(int orderId) {
    final viewedOrders = _storage.read<List>('viewed_order_updates') ?? [];
    return viewedOrders.contains(orderId);
  }

  /// Load stored status data
  Future<void> _loadStoredStatusData() async {
    try {
      // Load order statuses
      final storedStatuses = _storage.read<Map>('order_statuses');
      if (storedStatuses != null) {
        _orderStatuses.addAll(Map<int, String>.from(
          storedStatuses.map((key, value) => MapEntry(int.parse(key), value))
        ));
      }
      
      // Load status updates
      final storedUpdates = _storage.read<List>('order_status_updates');
      if (storedUpdates != null) {
        for (final updateData in storedUpdates) {
          try {
            _orderUpdates.add(OrderStatusUpdate.fromJson(updateData));
          } catch (e) {
            print('Error loading status update: $e');
          }
        }
      }
      
    } catch (e) {
      print('Error loading stored status data: $e');
    }
  }

  /// Save status data to storage
  void _saveStatusData() {
    try {
      // Save order statuses
      final statusesToSave = _orderStatuses.map(
        (key, value) => MapEntry(key.toString(), value)
      );
      _storage.write('order_statuses', statusesToSave);
      
      // Save status updates
      final updatesToSave = _orderUpdates.map((update) => update.toJson()).toList();
      _storage.write('order_status_updates', updatesToSave);
      
      // Save last check time
      _storage.write('last_status_check', DateTime.now().toIso8601String());
      
    } catch (e) {
      print('Error saving status data: $e');
    }
  }

  /// Clear old status data
  void clearOldStatusData() {
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));
    
    _orderUpdates.removeWhere(
      (update) => update.timestamp.isBefore(cutoffDate)
    );
    
    print('🧹 Cleared old status data older than 30 days');
  }

  /// Get real-time order status (bypasses cache)
  Future<String?> getRealTimeOrderStatus(int orderId) async {
    try {
      final order = await ApiService.getOrderById(orderId);
      return order?.status.toString();
    } catch (e) {
      print('Error getting real-time status for order $orderId: $e');
      return null;
    }
  }

  /// Subscribe to order status updates for specific order
  StreamSubscription<String>? subscribeToOrderStatus(
    int orderId, 
    Function(String) onStatusChange
  ) {
    // Create a stream that emits when order status changes
    return _orderStatuses.listen((statuses) {
      final status = statuses[orderId];
      if (status != null) {
        onStatusChange(status);
      }
    });
  }

  /// Get orders grouped by status
  Map<String, List<int>> getOrdersGroupedByStatus() {
    final grouped = <String, List<int>>{};
    
    for (final entry in _orderStatuses.entries) {
      final status = entry.value;
      grouped.putIfAbsent(status, () => []).add(entry.key);
    }
    
    return grouped;
  }
}

class OrderStatusUpdate {
  final int orderId;
  final String oldStatus;
  final String newStatus;
  final DateTime timestamp;

  OrderStatusUpdate({
    required this.orderId,
    required this.oldStatus,
    required this.newStatus,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OrderStatusUpdate.fromJson(Map<String, dynamic> json) {
    return OrderStatusUpdate(
      orderId: json['orderId'],
      oldStatus: json['oldStatus'],
      newStatus: json['newStatus'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Get user-friendly status change description
  String get description {
    final oldInfo = _getStatusInfo(oldStatus);
    final newInfo = _getStatusInfo(newStatus);
    return 'Changed from ${oldInfo['label']} to ${newInfo['label']}';
  }

  /// Get status information
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return {'label': 'Draft', 'color': 'grey'};
      case 'PENDING':
        return {'label': 'Pending Review', 'color': 'orange'};
      case 'APPROVED':
        return {'label': 'Approved', 'color': 'green'};
      case 'REJECTED':
        return {'label': 'Rejected', 'color': 'red'};
      case 'IN_PROGRESS':
        return {'label': 'In Progress', 'color': 'blue'};
      case 'DELIVERED':
        return {'label': 'Delivered', 'color': 'purple'};
      case 'CANCELLED':
        return {'label': 'Cancelled', 'color': 'grey'};
      default:
        return {'label': status, 'color': 'grey'};
    }
  }
}