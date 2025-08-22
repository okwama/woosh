import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/services/enhanced_geofencing_service.dart';
import 'package:get_storage/get_storage.dart';

class RoutePlanLockingService extends GetxService {
  static RoutePlanLockingService get instance => Get.find<RoutePlanLockingService>();

  final GetStorage _storage = GetStorage();
  
  // Observable data
  final RxBool _isRouteLocked = false.obs;
  final RxDouble _routeCompletionPercentage = 0.0.obs;
  final RxList<JourneyPlan> _lockedRoute = <JourneyPlan>[].obs;
  final RxInt _currentVisitIndex = 0.obs;
  final RxBool _allowRouteDeviation = false.obs;

  // Getters
  bool get isRouteLocked => _isRouteLocked.value;
  double get routeCompletionPercentage => _routeCompletionPercentage.value;
  List<JourneyPlan> get lockedRoute => _lockedRoute;
  int get currentVisitIndex => _currentVisitIndex.value;
  bool get allowRouteDeviation => _allowRouteDeviation.value;

  // Route locking configuration
  static const double maxDeviationDistance = 500.0; // 500 meters max deviation
  static const int routeLockGracePeriodMinutes = 30; // 30 minutes grace period after start

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadRouteState();
  }

  /// Load saved route state
  Future<void> _loadRouteState() async {
    try {
      final routeData = _storage.read<Map>('locked_route_state');
      if (routeData != null) {
        _isRouteLocked.value = routeData['isLocked'] ?? false;
        _currentVisitIndex.value = routeData['currentIndex'] ?? 0;
        _allowRouteDeviation.value = routeData['allowDeviation'] ?? false;
        
        // Load route plans if available
        final routePlansData = routeData['routePlans'] as List?;
        if (routePlansData != null) {
          _lockedRoute.clear();
          for (final planData in routePlansData) {
            _lockedRoute.add(JourneyPlan.fromJson(planData));
          }
          _calculateRouteCompletion();
        }
      }
    } catch (e) {
      print('Error loading route state: $e');
    }
  }

  /// Save route state
  Future<void> _saveRouteState() async {
    try {
      final routeData = {
        'isLocked': _isRouteLocked.value,
        'currentIndex': _currentVisitIndex.value,
        'allowDeviation': _allowRouteDeviation.value,
        'routePlans': _lockedRoute.map((plan) => plan.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _storage.write('locked_route_state', routeData);
    } catch (e) {
      print('Error saving route state: $e');
    }
  }

  /// Lock route plan for the day
  Future<bool> lockRouteForToday({bool forceOverride = false}) async {
    try {
      // Get today's journey plans
      final todayPlans = await _getTodayJourneyPlans();
      
      if (todayPlans.isEmpty) {
        Get.snackbar(
          'No Route Available',
          'No journey plans found for today. Please create a route first.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // Check if route is already locked
      if (_isRouteLocked.value && !forceOverride) {
        final shouldOverride = await _showRouteLockOverrideDialog();
        if (!shouldOverride) return false;
      }

      // Optimize route order
      final optimizedRoute = await _optimizeRouteOrder(todayPlans);
      
      // Lock the route
      _lockedRoute.clear();
      _lockedRoute.addAll(optimizedRoute);
      _isRouteLocked.value = true;
      _currentVisitIndex.value = 0;
      _allowRouteDeviation.value = false;
      
      await _saveRouteState();
      _calculateRouteCompletion();
      
      Get.snackbar(
        'Route Locked',
        'Today\'s route has been locked with ${optimizedRoute.length} visits. Follow the planned sequence for optimal efficiency.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
      
      return true;
      
    } catch (e) {
      print('Error locking route: $e');
      Get.snackbar(
        'Route Lock Failed',
        'Failed to lock route: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  /// Get today's journey plans
  Future<List<JourneyPlan>> _getTodayJourneyPlans() async {
    final today = DateTime.now();
    return await ApiService.getJourneyPlansByDate(today);
  }

  /// Optimize route order for efficiency
  Future<List<JourneyPlan>> _optimizeRouteOrder(List<JourneyPlan> plans) async {
    try {
      final geofencingService = Get.find<EnhancedGeofencingService>();
      final currentPosition = geofencingService.currentPosition.value;
      
      if (currentPosition == null || plans.length <= 1) {
        return plans; // Return as-is if no position or single plan
      }

      // Simple nearest-neighbor optimization
      final optimizedPlans = <JourneyPlan>[];
      final remainingPlans = List<JourneyPlan>.from(plans);
      
      double currentLat = currentPosition.latitude;
      double currentLng = currentPosition.longitude;
      
      while (remainingPlans.isNotEmpty) {
        JourneyPlan? nearestPlan;
        double nearestDistance = double.infinity;
        
        for (final plan in remainingPlans) {
          if (plan.client.latitude != null && plan.client.longitude != null) {
            final distance = _calculateDistance(
              currentLat, currentLng,
              plan.client.latitude!, plan.client.longitude!,
            );
            
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestPlan = plan;
            }
          }
        }
        
        if (nearestPlan != null) {
          optimizedPlans.add(nearestPlan);
          remainingPlans.remove(nearestPlan);
          currentLat = nearestPlan.client.latitude!;
          currentLng = nearestPlan.client.longitude!;
        } else {
          // Add remaining plans without location data
          optimizedPlans.addAll(remainingPlans);
          break;
        }
      }
      
      print('📍 Route optimized: ${plans.length} visits ordered by proximity');
      return optimizedPlans;
      
    } catch (e) {
      print('Route optimization failed: $e');
      return plans; // Return original order if optimization fails
    }
  }

  /// Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  /// Show route lock override dialog
  Future<bool> _showRouteLockOverrideDialog() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Route Already Locked'),
          ],
        ),
        content: Text(
          'A route is already locked for today. Overriding will reset your current progress. '
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Override', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Check if user can visit next location
  Future<RouteValidationResult> validateNextVisit(JourneyPlan targetPlan) async {
    if (!_isRouteLocked.value) {
      return RouteValidationResult(
        canProceed: true,
        message: 'Route not locked - free navigation allowed',
      );
    }

    // Check if this is the next planned visit
    if (_currentVisitIndex.value < _lockedRoute.length) {
      final nextPlannedVisit = _lockedRoute[_currentVisitIndex.value];
      
      if (targetPlan.id == nextPlannedVisit.id) {
        return RouteValidationResult(
          canProceed: true,
          message: 'This is your next planned visit',
        );
      }
    }

    // Check if deviation is allowed
    if (_allowRouteDeviation.value) {
      return RouteValidationResult(
        canProceed: true,
        message: 'Route deviation allowed',
        isDeviation: true,
      );
    }

    // Check if this is an emergency or approved deviation
    final isEmergencyVisit = await _checkEmergencyVisit(targetPlan);
    if (isEmergencyVisit) {
      return RouteValidationResult(
        canProceed: true,
        message: 'Emergency visit approved',
        isDeviation: true,
      );
    }

    return RouteValidationResult(
      canProceed: false,
      message: 'Please follow the planned route sequence. Next visit: ${_getNextPlannedVisitName()}',
      suggestedAction: 'Go to next planned visit',
    );
  }

  /// Check if visit is marked as emergency
  Future<bool> _checkEmergencyVisit(JourneyPlan plan) async {
    // This would check if the visit is marked as emergency in your system
    // For now, return false
    return false;
  }

  /// Get next planned visit name
  String _getNextPlannedVisitName() {
    if (_currentVisitIndex.value < _lockedRoute.length) {
      return _lockedRoute[_currentVisitIndex.value].client.name;
    }
    return 'No more visits planned';
  }

  /// Mark visit as completed and advance route
  Future<void> completeCurrentVisit(JourneyPlan completedPlan) async {
    if (!_isRouteLocked.value) return;

    // Find the completed visit in the locked route
    final completedIndex = _lockedRoute.indexWhere(
      (plan) => plan.id == completedPlan.id
    );

    if (completedIndex != -1) {
      // Update the plan status in locked route
      _lockedRoute[completedIndex] = completedPlan.copyWith(isCompleted: true);
      
      // Advance to next visit if this was the current one
      if (completedIndex == _currentVisitIndex.value) {
        _currentVisitIndex.value++;
      }
      
      _calculateRouteCompletion();
      await _saveRouteState();
      
      // Check if route is completed
      if (_routeCompletionPercentage.value >= 100.0) {
        await _handleRouteCompletion();
      }
    }
  }

  /// Calculate route completion percentage
  void _calculateRouteCompletion() {
    if (_lockedRoute.isEmpty) {
      _routeCompletionPercentage.value = 0.0;
      return;
    }

    final completedVisits = _lockedRoute.where((plan) => plan.isCompleted).length;
    _routeCompletionPercentage.value = (completedVisits / _lockedRoute.length) * 100;
  }

  /// Handle route completion
  Future<void> _handleRouteCompletion() async {
    Get.snackbar(
      'Route Completed! 🎉',
      'Congratulations! You have completed 100% of your planned route for today.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 5),
    );

    // Unlock route for any additional visits
    _allowRouteDeviation.value = true;
    await _saveRouteState();
    
    print('🏁 Route completed - allowing free navigation');
  }

  /// Unlock route (admin or emergency override)
  Future<bool> unlockRoute({String? reason}) async {
    if (!_isRouteLocked.value) {
      return true; // Already unlocked
    }

    final shouldUnlock = await _showRouteUnlockDialog(reason);
    if (!shouldUnlock) return false;

    _isRouteLocked.value = false;
    _allowRouteDeviation.value = true;
    await _saveRouteState();
    
    Get.snackbar(
      'Route Unlocked',
      'Route has been unlocked. You can now visit clients in any order.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    
    // Log the unlock event
    await _logRouteUnlock(reason);
    
    return true;
  }

  /// Show route unlock dialog
  Future<bool> _showRouteUnlockDialog(String? reason) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unlock Route'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to unlock the route?'),
            SizedBox(height: 12),
            Text(
              'This will allow you to visit clients in any order, but may impact route efficiency.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (reason != null) ...[
              SizedBox(height: 12),
              Text('Reason: $reason', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Unlock Route', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Log route unlock event
  Future<void> _logRouteUnlock(String? reason) async {
    try {
      final unlockEvents = _storage.read<List>('route_unlock_events') ?? [];
      unlockEvents.add({
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason ?? 'Manual unlock',
        'completionPercentage': _routeCompletionPercentage.value,
        'currentVisitIndex': _currentVisitIndex.value,
        'totalVisits': _lockedRoute.length,
      });
      
      // Keep only last 50 events
      if (unlockEvents.length > 50) {
        unlockEvents.removeRange(0, unlockEvents.length - 50);
      }
      
      await _storage.write('route_unlock_events', unlockEvents);
      
    } catch (e) {
      print('Error logging route unlock: $e');
    }
  }

  /// Get route coverage report
  Map<String, dynamic> getRouteCoverageReport() {
    if (!_isRouteLocked.value) {
      return {
        'error': 'No locked route available',
        'isLocked': false,
      };
    }

    final completedVisits = _lockedRoute.where((plan) => plan.isCompleted).length;
    final pendingVisits = _lockedRoute.where((plan) => !plan.isCompleted && !plan.isCancelled).length;
    final cancelledVisits = _lockedRoute.where((plan) => plan.isCancelled).length;
    
    return {
      'isLocked': true,
      'totalVisits': _lockedRoute.length,
      'completedVisits': completedVisits,
      'pendingVisits': pendingVisits,
      'cancelledVisits': cancelledVisits,
      'completionPercentage': _routeCompletionPercentage.value,
      'currentVisitIndex': _currentVisitIndex.value,
      'nextVisit': _getNextVisitInfo(),
      'allowsDeviation': _allowRouteDeviation.value,
    };
  }

  /// Get next visit information
  Map<String, dynamic>? _getNextVisitInfo() {
    if (_currentVisitIndex.value < _lockedRoute.length) {
      final nextVisit = _lockedRoute[_currentVisitIndex.value];
      return {
        'clientName': nextVisit.client.name,
        'clientId': nextVisit.client.id,
        'plannedTime': nextVisit.plannedStartTime?.toIso8601String(),
        'address': nextVisit.client.address,
      };
    }
    return null;
  }

  /// Check route deviation
  Future<RouteDeviationResult> checkRouteDeviation() async {
    if (!_isRouteLocked.value || _allowRouteDeviation.value) {
      return RouteDeviationResult(
        hasDeviation: false,
        message: 'Route deviation checking not active',
      );
    }

    try {
      final geofencingService = Get.find<EnhancedGeofencingService>();
      final currentPosition = geofencingService.currentPosition.value;
      
      if (currentPosition == null) {
        return RouteDeviationResult(
          hasDeviation: false,
          message: 'Current location not available',
        );
      }

      if (_currentVisitIndex.value >= _lockedRoute.length) {
        return RouteDeviationResult(
          hasDeviation: false,
          message: 'All visits completed',
        );
      }

      final nextPlannedVisit = _lockedRoute[_currentVisitIndex.value];
      
      if (nextPlannedVisit.client.latitude == null || nextPlannedVisit.client.longitude == null) {
        return RouteDeviationResult(
          hasDeviation: false,
          message: 'Next visit location not available',
        );
      }

      final distanceToNextVisit = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        nextPlannedVisit.client.latitude!,
        nextPlannedVisit.client.longitude!,
      );

      final hasDeviation = distanceToNextVisit > maxDeviationDistance;
      
      return RouteDeviationResult(
        hasDeviation: hasDeviation,
        distance: distanceToNextVisit,
        nextVisitName: nextPlannedVisit.client.name,
        message: hasDeviation 
          ? 'You are ${distanceToNextVisit.toStringAsFixed(0)}m away from your next planned visit'
          : 'You are on track to your next visit',
      );
      
    } catch (e) {
      print('Error checking route deviation: $e');
      return RouteDeviationResult(
        hasDeviation: false,
        message: 'Error checking route deviation',
      );
    }
  }

  /// Get route efficiency metrics
  Map<String, dynamic> getRouteEfficiencyMetrics() {
    if (!_isRouteLocked.value) {
      return {'error': 'No locked route available'};
    }

    final completedVisits = _lockedRoute.where((plan) => plan.isCompleted).toList();
    
    if (completedVisits.length < 2) {
      return {
        'totalDistance': 0.0,
        'averageVisitTime': 0.0,
        'efficiency': 'Insufficient data',
      };
    }

    // Calculate total distance traveled
    double totalDistance = 0.0;
    for (int i = 0; i < completedVisits.length - 1; i++) {
      final current = completedVisits[i];
      final next = completedVisits[i + 1];
      
      if (current.client.latitude != null && current.client.longitude != null &&
          next.client.latitude != null && next.client.longitude != null) {
        totalDistance += _calculateDistance(
          current.client.latitude!, current.client.longitude!,
          next.client.latitude!, next.client.longitude!,
        );
      }
    }

    return {
      'totalDistance': totalDistance,
      'averageDistanceBetweenVisits': completedVisits.length > 1 
          ? totalDistance / (completedVisits.length - 1) 
          : 0.0,
      'completedVisits': completedVisits.length,
      'efficiency': _calculateRouteEfficiency(),
    };
  }

  /// Calculate route efficiency score
  String _calculateRouteEfficiency() {
    final completionRate = _routeCompletionPercentage.value;
    
    if (completionRate >= 95) {
      return 'Excellent';
    } else if (completionRate >= 80) {
      return 'Good';
    } else if (completionRate >= 60) {
      return 'Fair';
    } else {
      return 'Needs Improvement';
    }
  }

  /// Enable route deviation temporarily
  void enableRouteDeviation({Duration? duration}) {
    _allowRouteDeviation.value = true;
    _saveRouteState();
    
    Get.snackbar(
      'Route Deviation Enabled',
      'You can now visit clients out of sequence.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );

    // Auto-disable after duration if specified
    if (duration != null) {
      Timer(duration, () {
        _allowRouteDeviation.value = false;
        _saveRouteState();
        
        Get.snackbar(
          'Route Deviation Disabled',
          'Please return to following the planned route sequence.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      });
    }
  }

  /// Reset route for new day
  Future<void> resetRouteForNewDay() async {
    _isRouteLocked.value = false;
    _lockedRoute.clear();
    _currentVisitIndex.value = 0;
    _routeCompletionPercentage.value = 0.0;
    _allowRouteDeviation.value = false;
    
    await _saveRouteState();
    
    print('🔄 Route reset for new day');
  }

  /// Get route unlock events for reporting
  List<Map<String, dynamic>> getRouteUnlockEvents() {
    return List<Map<String, dynamic>>.from(
      _storage.read<List>('route_unlock_events') ?? []
    );
  }
}

class RouteValidationResult {
  final bool canProceed;
  final String message;
  final bool isDeviation;
  final String? suggestedAction;

  RouteValidationResult({
    required this.canProceed,
    required this.message,
    this.isDeviation = false,
    this.suggestedAction,
  });
}

class RouteDeviationResult {
  final bool hasDeviation;
  final double? distance;
  final String? nextVisitName;
  final String message;

  RouteDeviationResult({
    required this.hasDeviation,
    this.distance,
    this.nextVisitName,
    required this.message,
  });
}