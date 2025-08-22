import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/performance_monitor_service.dart';

class EnhancedOfflineService extends GetxService {
  static EnhancedOfflineService get instance => Get.find<EnhancedOfflineService>();

  final GetStorage _storage = GetStorage();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  bool _isOnline = false;
  bool _isSyncing = false;
  Timer? _syncTimer;
  Timer? _retryTimer;
  
  // Sync configuration
  static const int syncIntervalSeconds = 30; // Sync every 30 seconds when online
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 10;
  
  // Offline data queues
  final List<OfflineOperation> _pendingOperations = [];
  final List<SyncError> _syncErrors = [];

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeOfflineCapabilities();
    _startConnectivityMonitoring();
    _loadPendingOperations();
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    _savePendingOperations();
    super.onClose();
  }

  /// Initialize offline capabilities
  Future<void> _initializeOfflineCapabilities() async {
    try {
      // Initialize offline storage
      await _initializeOfflineStorage();
      
      // Cache essential data for offline use
      await _cacheEssentialData();
      
      print('✅ Offline capabilities initialized');
    } catch (e) {
      print('❌ Failed to initialize offline capabilities: $e');
    }
  }

  /// Initialize offline storage
  Future<void> _initializeOfflineStorage() async {
    // Create offline data structure if it doesn't exist
    if (!_storage.hasData('offline_data_initialized')) {
      await _storage.write('offline_clients', <String, dynamic>{});
      await _storage.write('offline_products', <String, dynamic>{});
      await _storage.write('offline_orders', <String, dynamic>{});
      await _storage.write('offline_reports', <String, dynamic>{});
      await _storage.write('offline_data_initialized', true);
    }
  }

  /// Cache essential data for offline use
  Future<void> _cacheEssentialData() async {
    if (!_isOnline) return;

    try {
      // Cache frequently accessed data
      await _cacheClients();
      await _cacheProducts();
      await _cacheUserProfile();
      
      print('✅ Essential data cached for offline use');
    } catch (e) {
      print('⚠️ Failed to cache some essential data: $e');
    }
  }

  /// Cache clients data
  Future<void> _cacheClients() async {
    try {
      final clients = await ApiService.getClients();
      final clientsMap = <String, dynamic>{};
      
      for (final client in clients) {
        clientsMap[client.id.toString()] = client.toJson();
      }
      
      await _storage.write('offline_clients', clientsMap);
      await _storage.write('clients_cache_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to cache clients: $e');
    }
  }

  /// Cache products data
  Future<void> _cacheProducts() async {
    try {
      final products = await ApiService.getProducts();
      final productsMap = <String, dynamic>{};
      
      for (final product in products) {
        productsMap[product.id.toString()] = product.toJson();
      }
      
      await _storage.write('offline_products', productsMap);
      await _storage.write('products_cache_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to cache products: $e');
    }
  }

  /// Cache user profile
  Future<void> _cacheUserProfile() async {
    try {
      // This would cache user profile data
      // Implementation depends on your user profile API
      await _storage.write('profile_cache_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to cache user profile: $e');
    }
  }

  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );
    
    // Check initial connectivity
    _checkInitialConnectivity();
  }

  /// Check initial connectivity
  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChange(results);
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );

    if (_isOnline && !wasOnline) {
      _onConnectivityRestored();
    } else if (!_isOnline && wasOnline) {
      _onConnectivityLost();
    }
  }

  /// Handle connectivity restored
  void _onConnectivityRestored() async {
    print('🌐 Connectivity restored - starting sync');
    
    Get.snackbar(
      'Back Online',
      'Connection restored. Syncing data...',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );

    // Start automatic syncing
    _startAutomaticSync();
    
    // Trigger immediate sync
    await _performSync();
    
    // Refresh essential data
    await _cacheEssentialData();
  }

  /// Handle connectivity lost
  void _onConnectivityLost() {
    print('📵 Connectivity lost - switching to offline mode');
    
    Get.snackbar(
      'Offline Mode',
      'No internet connection. Working in offline mode.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );

    _stopAutomaticSync();
  }

  /// Start automatic sync when online
  void _startAutomaticSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(seconds: syncIntervalSeconds),
      (_) => _performSync(),
    );
  }

  /// Stop automatic sync
  void _stopAutomaticSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform data synchronization
  Future<void> _performSync() async {
    if (!_isOnline || _isSyncing) return;

    _isSyncing = true;
    
    try {
      final performanceMonitor = Get.find<PerformanceMonitorService>();
      performanceMonitor.startOperation('sync_${DateTime.now().millisecondsSinceEpoch}', 'data_sync');

      // Sync pending operations
      await _syncPendingOperations();
      
      // Sync field data
      await _syncFieldData();
      
      // Update cached data if needed
      await _updateCachedDataIfNeeded();

      performanceMonitor.endOperation('sync_${DateTime.now().millisecondsSinceEpoch}', 'data_sync', wasSuccessful: true);
      
      print('✅ Sync completed successfully');
      
    } catch (e) {
      print('❌ Sync failed: $e');
      _recordSyncError(e.toString());
      
      final performanceMonitor = Get.find<PerformanceMonitorService>();
      performanceMonitor.endOperation('sync_${DateTime.now().millisecondsSinceEpoch}', 'data_sync', 
        wasSuccessful: false, errorMessage: e.toString());
      
      // Schedule retry
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending operations
  Future<void> _syncPendingOperations() async {
    final operationsToSync = List<OfflineOperation>.from(_pendingOperations);
    
    for (final operation in operationsToSync) {
      try {
        await _executePendingOperation(operation);
        _pendingOperations.remove(operation);
      } catch (e) {
        operation.retryCount++;
        if (operation.retryCount >= maxRetryAttempts) {
          _pendingOperations.remove(operation);
          _recordSyncError('Max retries exceeded for operation: ${operation.type}');
        }
      }
    }
  }

  /// Execute a pending operation
  Future<void> _executePendingOperation(OfflineOperation operation) async {
    switch (operation.type) {
      case 'order_submit':
        await _syncPendingOrder(operation.data);
        break;
      case 'checkin':
        await _syncPendingCheckin(operation.data);
        break;
      case 'checkout':
        await _syncPendingCheckout(operation.data);
        break;
      case 'report_submit':
        await _syncPendingReport(operation.data);
        break;
      default:
        print('Unknown operation type: ${operation.type}');
    }
  }

  /// Sync pending order
  Future<void> _syncPendingOrder(Map<String, dynamic> orderData) async {
    // Implementation would depend on your order API
    await ApiService.createOrder(orderData);
  }

  /// Sync pending checkin
  Future<void> _syncPendingCheckin(Map<String, dynamic> checkinData) async {
    // Implementation would depend on your checkin API
    // await ApiService.submitCheckin(checkinData);
  }

  /// Sync pending checkout
  Future<void> _syncPendingCheckout(Map<String, dynamic> checkoutData) async {
    // Implementation would depend on your checkout API
    // await ApiService.submitCheckout(checkoutData);
  }

  /// Sync pending report
  Future<void> _syncPendingReport(Map<String, dynamic> reportData) async {
    // Implementation would depend on your report API
    // await ApiService.submitReport(reportData);
  }

  /// Sync field data with backend
  Future<void> _syncFieldData() async {
    try {
      // Sync journey plans
      await _syncJourneyPlans();
      
      // Sync session data
      await _syncSessionData();
      
      // Sync any other field-specific data
      
    } catch (e) {
      print('Failed to sync field data: $e');
      throw e;
    }
  }

  /// Sync journey plans
  Future<void> _syncJourneyPlans() async {
    try {
      final pendingService = Get.find<PendingJourneyPlanHiveService>();
      final pendingPlans = await pendingService.getAllPendingPlans();
      
      for (final plan in pendingPlans) {
        try {
          // Sync individual journey plan
          await ApiService.syncJourneyPlan(plan);
          await pendingService.removePendingPlan(plan.id);
        } catch (e) {
          print('Failed to sync journey plan ${plan.id}: $e');
        }
      }
    } catch (e) {
      print('Failed to sync journey plans: $e');
    }
  }

  /// Sync session data
  Future<void> _syncSessionData() async {
    try {
      final pendingService = Get.find<PendingSessionHiveService>();
      final pendingSessions = await pendingService.getAllPendingSessions();
      
      for (final session in pendingSessions) {
        try {
          // Sync individual session
          await ApiService.syncSession(session);
          await pendingService.removePendingSession(session.id);
        } catch (e) {
          print('Failed to sync session ${session.id}: $e');
        }
      }
    } catch (e) {
      print('Failed to sync session data: $e');
    }
  }

  /// Update cached data if needed
  Future<void> _updateCachedDataIfNeeded() async {
    final now = DateTime.now();
    
    // Check if clients cache needs update (older than 1 hour)
    final clientsCacheTime = _storage.read<String>('clients_cache_time');
    if (clientsCacheTime == null || 
        now.difference(DateTime.parse(clientsCacheTime)).inHours >= 1) {
      await _cacheClients();
    }
    
    // Check if products cache needs update (older than 2 hours)
    final productsCacheTime = _storage.read<String>('products_cache_time');
    if (productsCacheTime == null || 
        now.difference(DateTime.parse(productsCacheTime)).inHours >= 2) {
      await _cacheProducts();
    }
  }

  /// Add operation to offline queue
  void queueOfflineOperation(String type, Map<String, dynamic> data) {
    final operation = OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
      retryCount: 0,
    );
    
    _pendingOperations.add(operation);
    _savePendingOperations();
    
    print('📝 Queued offline operation: $type');
    
    // Show user feedback
    Get.snackbar(
      'Saved Offline',
      'Your action has been saved and will sync when connection is restored.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }

  /// Record sync error
  void _recordSyncError(String error) {
    final syncError = SyncError(
      error: error,
      timestamp: DateTime.now(),
      pendingOperationsCount: _pendingOperations.length,
    );
    
    _syncErrors.add(syncError);
    
    // Keep only last 20 errors
    if (_syncErrors.length > 20) {
      _syncErrors.removeRange(0, _syncErrors.length - 20);
    }
    
    print('❌ Sync error recorded: $error');
  }

  /// Schedule retry for failed sync
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: retryDelaySeconds), () {
      if (_isOnline) {
        _performSync();
      }
    });
  }

  /// Load pending operations from storage
  void _loadPendingOperations() {
    final storedOperations = _storage.read<List>('pending_operations');
    if (storedOperations != null) {
      for (final opData in storedOperations) {
        try {
          _pendingOperations.add(OfflineOperation.fromJson(opData));
        } catch (e) {
          print('Error loading pending operation: $e');
        }
      }
    }
  }

  /// Save pending operations to storage
  void _savePendingOperations() {
    final operationsData = _pendingOperations.map((op) => op.toJson()).toList();
    _storage.write('pending_operations', operationsData);
  }

  /// Get offline status info
  Map<String, dynamic> getOfflineStatus() {
    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'pendingOperationsCount': _pendingOperations.length,
      'syncErrorsCount': _syncErrors.length,
      'lastSyncAttempt': _storage.read<String>('last_sync_attempt'),
      'hasOfflineData': _hasOfflineData(),
    };
  }

  /// Check if offline data is available
  bool _hasOfflineData() {
    final clients = _storage.read<Map>('offline_clients');
    final products = _storage.read<Map>('offline_products');
    
    return (clients?.isNotEmpty ?? false) || (products?.isNotEmpty ?? false);
  }

  /// Get cached clients for offline use
  List<Map<String, dynamic>> getCachedClients() {
    final clientsMap = _storage.read<Map>('offline_clients') ?? {};
    return clientsMap.values.cast<Map<String, dynamic>>().toList();
  }

  /// Get cached products for offline use
  List<Map<String, dynamic>> getCachedProducts() {
    final productsMap = _storage.read<Map>('offline_products') ?? {};
    return productsMap.values.cast<Map<String, dynamic>>().toList();
  }

  /// Force sync now (manual trigger)
  Future<bool> forceSyncNow() async {
    if (!_isOnline) {
      Get.snackbar(
        'No Connection',
        'Cannot sync while offline. Please check your internet connection.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return false;
    }

    try {
      await _performSync();
      
      Get.snackbar(
        'Sync Complete',
        'All data has been synchronized successfully.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return true;
    } catch (e) {
      Get.snackbar(
        'Sync Failed',
        'Failed to sync data: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return false;
    }
  }

  /// Get sync errors for debugging
  List<SyncError> getSyncErrors() {
    return List<SyncError>.from(_syncErrors);
  }

  /// Clear sync errors
  void clearSyncErrors() {
    _syncErrors.clear();
  }

  /// Check if specific data type is available offline
  bool isDataAvailableOffline(String dataType) {
    switch (dataType) {
      case 'clients':
        return (_storage.read<Map>('offline_clients')?.isNotEmpty ?? false);
      case 'products':
        return (_storage.read<Map>('offline_products')?.isNotEmpty ?? false);
      default:
        return false;
    }
  }
}

class OfflineOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    required this.retryCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

class SyncError {
  final String error;
  final DateTime timestamp;
  final int pendingOperationsCount;

  SyncError({
    required this.error,
    required this.timestamp,
    required this.pendingOperationsCount,
  });
}