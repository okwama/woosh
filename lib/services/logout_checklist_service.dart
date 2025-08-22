import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/services/enhanced_offline_service.dart';
import 'package:geolocator/geolocator.dart';

class LogoutChecklistService extends GetxService {
  static LogoutChecklistService get instance => Get.find<LogoutChecklistService>();

  // Checklist items status
  final RxBool _allVisitsCompleted = false.obs;
  final RxBool _allOrdersSubmitted = false.obs;
  final RxBool _gpsActive = false.obs;
  final RxBool _dataSync = false.obs;
  final RxBool _reportSubmitted = false.obs;
  
  // Getters for checklist status
  bool get allVisitsCompleted => _allVisitsCompleted.value;
  bool get allOrdersSubmitted => _allOrdersSubmitted.value;
  bool get gpsActive => _gpsActive.value;
  bool get dataSync => _dataSync.value;
  bool get reportSubmitted => _reportSubmitted.value;

  /// Check if all logout requirements are met
  bool get canLogout => 
    _allVisitsCompleted.value && 
    _allOrdersSubmitted.value && 
    _gpsActive.value && 
    _dataSync.value;

  /// Get checklist completion percentage
  double get completionPercentage {
    int completed = 0;
    int total = 5; // Total checklist items
    
    if (_allVisitsCompleted.value) completed++;
    if (_allOrdersSubmitted.value) completed++;
    if (_gpsActive.value) completed++;
    if (_dataSync.value) completed++;
    if (_reportSubmitted.value) completed++;
    
    return completed / total;
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeChecklist();
  }

  /// Initialize checklist by checking current status
  Future<void> _initializeChecklist() async {
    await _checkAllVisitsCompleted();
    await _checkAllOrdersSubmitted();
    await _checkGpsStatus();
    await _checkDataSyncStatus();
    await _checkReportStatus();
  }

  /// Check if all scheduled visits are completed
  Future<void> _checkAllVisitsCompleted() async {
    try {
      final todayPlans = await JourneyPlanService.getTodayJourneyPlans();
      final incompleteVisits = todayPlans.where(
        (plan) => !plan.isCompleted && !plan.isCancelled
      ).toList();
      
      _allVisitsCompleted.value = incompleteVisits.isEmpty;
      
      if (incompleteVisits.isNotEmpty) {
        print('⚠️ ${incompleteVisits.length} visits still pending');
      }
    } catch (e) {
      print('Error checking visits status: $e');
      _allVisitsCompleted.value = false;
    }
  }

  /// Check if all orders are submitted
  Future<void> _checkAllOrdersSubmitted() async {
    try {
      // Check for draft orders
      final draftOrders = await ApiService.getOrdersByStatus('DRAFT');
      _allOrdersSubmitted.value = draftOrders.isEmpty;
      
      if (draftOrders.isNotEmpty) {
        print('⚠️ ${draftOrders.length} draft orders need to be submitted');
      }
    } catch (e) {
      print('Error checking orders status: $e');
      _allOrdersSubmitted.value = false;
    }
  }

  /// Check GPS status
  Future<void> _checkGpsStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      
      _gpsActive.value = serviceEnabled && 
        (permission == LocationPermission.always || 
         permission == LocationPermission.whileInUse);
         
      if (!_gpsActive.value) {
        print('⚠️ GPS not active or permission not granted');
      }
    } catch (e) {
      print('Error checking GPS status: $e');
      _gpsActive.value = false;
    }
  }

  /// Check data synchronization status
  Future<void> _checkDataSyncStatus() async {
    try {
      final offlineService = Get.find<EnhancedOfflineService>();
      final status = offlineService.getOfflineStatus();
      
      _dataSync.value = status['isOnline'] && 
        status['pendingOperationsCount'] == 0 &&
        status['syncErrorsCount'] == 0;
        
      if (!_dataSync.value) {
        print('⚠️ Data sync issues detected');
      }
    } catch (e) {
      print('Error checking data sync status: $e');
      _dataSync.value = false;
    }
  }

  /// Check if daily report is submitted
  Future<void> _checkReportStatus() async {
    try {
      // Check if today's report has been submitted
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // This would check your reports API
      // final report = await ApiService.getDailyReport(todayStr);
      // _reportSubmitted.value = report != null;
      
      // For now, assume report is optional
      _reportSubmitted.value = true;
    } catch (e) {
      print('Error checking report status: $e');
      _reportSubmitted.value = false;
    }
  }

  /// Refresh checklist status
  Future<void> refreshChecklist() async {
    await _initializeChecklist();
  }

  /// Show logout checklist dialog
  Future<bool> showLogoutChecklist() async {
    await refreshChecklist();
    
    if (canLogout) {
      return await _showConfirmationDialog();
    } else {
      return await _showChecklistDialog();
    }
  }

  /// Show confirmation dialog when all requirements are met
  Future<bool> _showConfirmationDialog() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Ready to Logout'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('All logout requirements have been completed:'),
            SizedBox(height: 16),
            _buildChecklistSummary(),
            SizedBox(height: 16),
            Text('Are you sure you want to logout?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Show checklist dialog with pending items
  Future<bool> _showChecklistDialog() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Logout Checklist'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please complete the following before logging out:'),
              SizedBox(height: 16),
              _buildDetailedChecklist(),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: completionPercentage,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionPercentage >= 0.8 ? Colors.green : Colors.orange,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${(completionPercentage * 100).toInt()}% Complete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          if (canLogout)
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Logout', style: TextStyle(color: Colors.white)),
            )
          else
            ElevatedButton(
              onPressed: () {
                Get.back(result: false);
                _navigateToIncompleteItems();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('Complete Tasks', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Build checklist summary for confirmation dialog
  Widget _buildChecklistSummary() {
    return Column(
      children: [
        _buildChecklistItem('All visits completed', _allVisitsCompleted.value),
        _buildChecklistItem('All orders submitted', _allOrdersSubmitted.value),
        _buildChecklistItem('GPS active', _gpsActive.value),
        _buildChecklistItem('Data synchronized', _dataSync.value),
        _buildChecklistItem('Daily report submitted', _reportSubmitted.value),
      ],
    );
  }

  /// Build detailed checklist for incomplete items
  Widget _buildDetailedChecklist() {
    return Column(
      children: [
        _buildDetailedChecklistItem(
          'Complete all scheduled visits',
          _allVisitsCompleted.value,
          _allVisitsCompleted.value ? null : 'Tap to view pending visits',
          () => Get.toNamed('/journey-plans'),
        ),
        _buildDetailedChecklistItem(
          'Submit all draft orders',
          _allOrdersSubmitted.value,
          _allOrdersSubmitted.value ? null : 'Tap to view draft orders',
          () => Get.toNamed('/orders?status=draft'),
        ),
        _buildDetailedChecklistItem(
          'Ensure GPS is active',
          _gpsActive.value,
          _gpsActive.value ? null : 'Tap to enable location services',
          () => _enableGPS(),
        ),
        _buildDetailedChecklistItem(
          'Synchronize all data',
          _dataSync.value,
          _dataSync.value ? null : 'Tap to sync now',
          () => _forceSyncData(),
        ),
        _buildDetailedChecklistItem(
          'Submit daily activity report',
          _reportSubmitted.value,
          _reportSubmitted.value ? null : 'Tap to submit report',
          () => Get.toNamed('/daily-report'),
        ),
      ],
    );
  }

  /// Build simple checklist item
  Widget _buildChecklistItem(String title, bool isCompleted) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }

  /// Build detailed checklist item with action
  Widget _buildDetailedChecklistItem(
    String title, 
    bool isCompleted, 
    String? subtitle,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: isCompleted ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.warning,
              color: isCompleted ? Colors.green : Colors.orange,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isCompleted ? Colors.green[700] : Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            if (!isCompleted)
              Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Navigate to incomplete items
  void _navigateToIncompleteItems() {
    if (!_allVisitsCompleted.value) {
      Get.toNamed('/journey-plans');
    } else if (!_allOrdersSubmitted.value) {
      Get.toNamed('/orders?status=draft');
    } else if (!_gpsActive.value) {
      _enableGPS();
    } else if (!_dataSync.value) {
      _forceSyncData();
    } else if (!_reportSubmitted.value) {
      Get.toNamed('/daily-report');
    }
  }

  /// Enable GPS
  Future<void> _enableGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      await _checkGpsStatus();
    } catch (e) {
      print('Error enabling GPS: $e');
      Get.snackbar(
        'GPS Error',
        'Failed to enable GPS. Please check your device settings.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Force data synchronization
  Future<void> _forceSyncData() async {
    try {
      final offlineService = Get.find<EnhancedOfflineService>();
      final success = await offlineService.forceSyncNow();
      
      if (success) {
        await _checkDataSyncStatus();
      }
    } catch (e) {
      print('Error forcing data sync: $e');
    }
  }

  /// Get checklist items for display
  List<ChecklistItem> getChecklistItems() {
    return [
      ChecklistItem(
        title: 'Complete all scheduled visits',
        isCompleted: _allVisitsCompleted.value,
        description: _allVisitsCompleted.value 
          ? 'All visits completed' 
          : 'Some visits are still pending',
        action: () => Get.toNamed('/journey-plans'),
        priority: ChecklistPriority.high,
      ),
      ChecklistItem(
        title: 'Submit all draft orders',
        isCompleted: _allOrdersSubmitted.value,
        description: _allOrdersSubmitted.value 
          ? 'All orders submitted' 
          : 'Some orders are still in draft',
        action: () => Get.toNamed('/orders?status=draft'),
        priority: ChecklistPriority.high,
      ),
      ChecklistItem(
        title: 'Ensure GPS is active',
        isCompleted: _gpsActive.value,
        description: _gpsActive.value 
          ? 'GPS is active and permissions granted' 
          : 'GPS needs to be enabled',
        action: () => _enableGPS(),
        priority: ChecklistPriority.medium,
      ),
      ChecklistItem(
        title: 'Synchronize all data',
        isCompleted: _dataSync.value,
        description: _dataSync.value 
          ? 'All data synchronized' 
          : 'Some data needs to be synchronized',
        action: () => _forceSyncData(),
        priority: ChecklistPriority.medium,
      ),
      ChecklistItem(
        title: 'Submit daily activity report',
        isCompleted: _reportSubmitted.value,
        description: _reportSubmitted.value 
          ? 'Daily report submitted' 
          : 'Daily report needs to be submitted',
        action: () => Get.toNamed('/daily-report'),
        priority: ChecklistPriority.low,
      ),
    ];
  }

  /// Get incomplete items count by priority
  Map<ChecklistPriority, int> getIncompleteItemsByPriority() {
    final items = getChecklistItems();
    final incomplete = items.where((item) => !item.isCompleted);
    
    final counts = <ChecklistPriority, int>{
      ChecklistPriority.high: 0,
      ChecklistPriority.medium: 0,
      ChecklistPriority.low: 0,
    };
    
    for (final item in incomplete) {
      counts[item.priority] = (counts[item.priority] ?? 0) + 1;
    }
    
    return counts;
  }

  /// Get blocking items (high priority incomplete items)
  List<ChecklistItem> getBlockingItems() {
    return getChecklistItems()
      .where((item) => !item.isCompleted && item.priority == ChecklistPriority.high)
      .toList();
  }

  /// Force complete all items (for testing or admin override)
  void forceCompleteAll() {
    _allVisitsCompleted.value = true;
    _allOrdersSubmitted.value = true;
    _gpsActive.value = true;
    _dataSync.value = true;
    _reportSubmitted.value = true;
  }

  /// Reset checklist
  void resetChecklist() {
    _allVisitsCompleted.value = false;
    _allOrdersSubmitted.value = false;
    _gpsActive.value = false;
    _dataSync.value = false;
    _reportSubmitted.value = false;
  }
}

class ChecklistItem {
  final String title;
  final bool isCompleted;
  final String description;
  final VoidCallback action;
  final ChecklistPriority priority;

  ChecklistItem({
    required this.title,
    required this.isCompleted,
    required this.description,
    required this.action,
    required this.priority,
  });
}

enum ChecklistPriority {
  high,
  medium,
  low,
}