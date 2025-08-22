import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/account_balance_service.dart';
import 'package:woosh/services/order_status_tracking_service.dart';
import 'package:get_storage/get_storage.dart';

class EnhancedManagerDashboardService extends GetxService {
  static EnhancedManagerDashboardService get instance => Get.find<EnhancedManagerDashboardService>();

  final GetStorage _storage = GetStorage();
  Timer? _dashboardUpdateTimer;
  
  // Observable dashboard data
  final Rx<ManagerDashboardData?> _dashboardData = Rx<ManagerDashboardData?>(null);
  final RxBool _isLoading = false.obs;
  final RxString _lastUpdateTime = ''.obs;

  // Configuration
  static const int dashboardUpdateIntervalMinutes = 5; // Update every 5 minutes
  static const int realtimeUpdateIntervalSeconds = 30; // Real-time updates every 30 seconds

  ManagerDashboardData? get dashboardData => _dashboardData.value;
  bool get isLoading => _isLoading.value;
  String get lastUpdateTime => _lastUpdateTime.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadCachedDashboardData();
    _startDashboardUpdates();
  }

  @override
  void onClose() {
    _dashboardUpdateTimer?.cancel();
    _saveDashboardData();
    super.onClose();
  }

  /// Start periodic dashboard updates
  void _startDashboardUpdates() {
    // Initial load
    _updateDashboard();
    
    // Periodic updates
    _dashboardUpdateTimer = Timer.periodic(
      Duration(minutes: dashboardUpdateIntervalMinutes),
      (_) => _updateDashboard(),
    );
  }

  /// Update dashboard with latest data
  Future<void> _updateDashboard() async {
    if (_isLoading.value) return;
    
    try {
      _isLoading.value = true;
      
      // Fetch all dashboard data in parallel
      final results = await Future.wait([
        _fetchSalesSummary(),
        _fetchVisitCompliance(),
        _fetchPerformanceTrends(),
        _fetchTeamMetrics(),
        _fetchRealtimeStatus(),
        _fetchAccountMasterData(),
      ]);

      final salesSummary = results[0] as Map<String, dynamic>;
      final visitCompliance = results[1] as Map<String, dynamic>;
      final performanceTrends = results[2] as Map<String, dynamic>;
      final teamMetrics = results[3] as Map<String, dynamic>;
      final realtimeStatus = results[4] as Map<String, dynamic>;
      final accountMasterData = results[5] as Map<String, dynamic>;

      _dashboardData.value = ManagerDashboardData(
        salesSummary: salesSummary,
        visitCompliance: visitCompliance,
        performanceTrends: performanceTrends,
        teamMetrics: teamMetrics,
        realtimeStatus: realtimeStatus,
        accountMasterData: accountMasterData,
        lastUpdated: DateTime.now(),
      );

      _lastUpdateTime.value = DateTime.now().toString();
      
      print('✅ Manager dashboard updated successfully');
      
    } catch (e) {
      print('❌ Failed to update manager dashboard: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Fetch sales summary data
  Future<Map<String, dynamic>> _fetchSalesSummary() async {
    try {
      final today = DateTime.now();
      final startOfMonth = DateTime(today.year, today.month, 1);
      
      // Get sales data for different periods
      final results = await Future.wait([
        ApiService.getSalesSummary(startOfMonth, today), // This month
        ApiService.getSalesSummary(today, today), // Today
        ApiService.getSalesSummary(today.subtract(Duration(days: 7)), today), // Last 7 days
      ]);

      return {
        'monthlyTotal': results[0]['totalAmount'] ?? 0.0,
        'monthlyOrders': results[0]['totalOrders'] ?? 0,
        'dailyTotal': results[1]['totalAmount'] ?? 0.0,
        'dailyOrders': results[1]['totalOrders'] ?? 0,
        'weeklyTotal': results[2]['totalAmount'] ?? 0.0,
        'weeklyOrders': results[2]['totalOrders'] ?? 0,
        'topProducts': results[0]['topProducts'] ?? [],
        'topClients': results[0]['topClients'] ?? [],
      };
    } catch (e) {
      print('Error fetching sales summary: $e');
      return _getEmptySalesSummary();
    }
  }

  /// Fetch visit compliance data
  Future<Map<String, dynamic>> _fetchVisitCompliance() async {
    try {
      final today = DateTime.now();
      final complianceData = await ApiService.getVisitCompliance(today);
      
      return {
        'totalPlannedVisits': complianceData['totalPlanned'] ?? 0,
        'completedVisits': complianceData['completed'] ?? 0,
        'pendingVisits': complianceData['pending'] ?? 0,
        'cancelledVisits': complianceData['cancelled'] ?? 0,
        'complianceRate': complianceData['complianceRate'] ?? 0.0,
        'averageVisitDuration': complianceData['avgDuration'] ?? 0.0,
        'onTimeVisits': complianceData['onTime'] ?? 0,
        'lateVisits': complianceData['late'] ?? 0,
      };
    } catch (e) {
      print('Error fetching visit compliance: $e');
      return _getEmptyVisitCompliance();
    }
  }

  /// Fetch performance trends
  Future<Map<String, dynamic>> _fetchPerformanceTrends() async {
    try {
      final trendsData = await ApiService.getPerformanceTrends();
      
      return {
        'salesTrend': trendsData['salesTrend'] ?? [],
        'visitTrend': trendsData['visitTrend'] ?? [],
        'performanceScore': trendsData['performanceScore'] ?? 0.0,
        'topPerformers': trendsData['topPerformers'] ?? [],
        'improvementAreas': trendsData['improvementAreas'] ?? [],
      };
    } catch (e) {
      print('Error fetching performance trends: $e');
      return _getEmptyPerformanceTrends();
    }
  }

  /// Fetch team metrics
  Future<Map<String, dynamic>> _fetchTeamMetrics() async {
    try {
      final teamData = await ApiService.getTeamMetrics();
      
      return {
        'totalReps': teamData['totalReps'] ?? 0,
        'activeReps': teamData['activeReps'] ?? 0,
        'repsOnRoute': teamData['repsOnRoute'] ?? 0,
        'avgPerformanceScore': teamData['avgPerformanceScore'] ?? 0.0,
        'teamTargetAchievement': teamData['teamTargetAchievement'] ?? 0.0,
        'repPerformance': teamData['repPerformance'] ?? [],
      };
    } catch (e) {
      print('Error fetching team metrics: $e');
      return _getEmptyTeamMetrics();
    }
  }

  /// Fetch real-time status
  Future<Map<String, dynamic>> _fetchRealtimeStatus() async {
    try {
      final statusData = await ApiService.getRealtimeStatus();
      
      return {
        'activeUsers': statusData['activeUsers'] ?? 0,
        'pendingOrders': statusData['pendingOrders'] ?? 0,
        'systemHealth': statusData['systemHealth'] ?? 'unknown',
        'serverLoad': statusData['serverLoad'] ?? 0.0,
        'lastSyncTime': statusData['lastSyncTime'],
        'alertsCount': statusData['alertsCount'] ?? 0,
      };
    } catch (e) {
      print('Error fetching real-time status: $e');
      return _getEmptyRealtimeStatus();
    }
  }

  /// Fetch account master data
  Future<Map<String, dynamic>> _fetchAccountMasterData() async {
    try {
      final masterData = await ApiService.getAccountMasterData();
      
      return {
        'totalAccounts': masterData['totalAccounts'] ?? 0,
        'activeAccounts': masterData['activeAccounts'] ?? 0,
        'duplicateAccounts': masterData['duplicateAccounts'] ?? [],
        'accountsWithoutCodes': masterData['accountsWithoutCodes'] ?? [],
        'dataQualityScore': masterData['dataQualityScore'] ?? 0.0,
        'lastDataCleanup': masterData['lastDataCleanup'],
      };
    } catch (e) {
      print('Error fetching account master data: $e');
      return _getEmptyAccountMasterData();
    }
  }

  /// Get empty sales summary (fallback)
  Map<String, dynamic> _getEmptySalesSummary() {
    return {
      'monthlyTotal': 0.0,
      'monthlyOrders': 0,
      'dailyTotal': 0.0,
      'dailyOrders': 0,
      'weeklyTotal': 0.0,
      'weeklyOrders': 0,
      'topProducts': [],
      'topClients': [],
    };
  }

  /// Get empty visit compliance (fallback)
  Map<String, dynamic> _getEmptyVisitCompliance() {
    return {
      'totalPlannedVisits': 0,
      'completedVisits': 0,
      'pendingVisits': 0,
      'cancelledVisits': 0,
      'complianceRate': 0.0,
      'averageVisitDuration': 0.0,
      'onTimeVisits': 0,
      'lateVisits': 0,
    };
  }

  /// Get empty performance trends (fallback)
  Map<String, dynamic> _getEmptyPerformanceTrends() {
    return {
      'salesTrend': [],
      'visitTrend': [],
      'performanceScore': 0.0,
      'topPerformers': [],
      'improvementAreas': [],
    };
  }

  /// Get empty team metrics (fallback)
  Map<String, dynamic> _getEmptyTeamMetrics() {
    return {
      'totalReps': 0,
      'activeReps': 0,
      'repsOnRoute': 0,
      'avgPerformanceScore': 0.0,
      'teamTargetAchievement': 0.0,
      'repPerformance': [],
    };
  }

  /// Get empty real-time status (fallback)
  Map<String, dynamic> _getEmptyRealtimeStatus() {
    return {
      'activeUsers': 0,
      'pendingOrders': 0,
      'systemHealth': 'unknown',
      'serverLoad': 0.0,
      'lastSyncTime': null,
      'alertsCount': 0,
    };
  }

  /// Get empty account master data (fallback)
  Map<String, dynamic> _getEmptyAccountMasterData() {
    return {
      'totalAccounts': 0,
      'activeAccounts': 0,
      'duplicateAccounts': [],
      'accountsWithoutCodes': [],
      'dataQualityScore': 0.0,
      'lastDataCleanup': null,
    };
  }

  /// Load cached dashboard data
  Future<void> _loadCachedDashboardData() async {
    try {
      final cachedData = _storage.read<Map>('cached_dashboard_data');
      if (cachedData != null) {
        _dashboardData.value = ManagerDashboardData.fromJson(cachedData);
        _lastUpdateTime.value = _dashboardData.value?.lastUpdated.toString() ?? '';
      }
    } catch (e) {
      print('Error loading cached dashboard data: $e');
    }
  }

  /// Save dashboard data to cache
  void _saveDashboardData() {
    try {
      if (_dashboardData.value != null) {
        _storage.write('cached_dashboard_data', _dashboardData.value!.toJson());
      }
    } catch (e) {
      print('Error saving dashboard data: $e');
    }
  }

  /// Force refresh dashboard
  Future<bool> forceRefreshDashboard() async {
    try {
      await _updateDashboard();
      return true;
    } catch (e) {
      print('Error forcing dashboard refresh: $e');
      return false;
    }
  }

  /// Get dashboard alerts
  List<DashboardAlert> getDashboardAlerts() {
    final alerts = <DashboardAlert>[];
    final data = _dashboardData.value;
    
    if (data == null) return alerts;

    // Check for low visit compliance
    final complianceRate = data.visitCompliance['complianceRate'] as double? ?? 0.0;
    if (complianceRate < 80.0) {
      alerts.add(DashboardAlert(
        type: AlertType.warning,
        title: 'Low Visit Compliance',
        message: 'Visit compliance rate is ${complianceRate.toStringAsFixed(1)}%',
        priority: AlertPriority.high,
      ));
    }

    // Check for pending orders
    final pendingOrders = data.realtimeStatus['pendingOrders'] as int? ?? 0;
    if (pendingOrders > 10) {
      alerts.add(DashboardAlert(
        type: AlertType.info,
        title: 'Pending Orders',
        message: '$pendingOrders orders awaiting approval',
        priority: AlertPriority.medium,
      ));
    }

    // Check for duplicate accounts
    final duplicateAccounts = data.accountMasterData['duplicateAccounts'] as List? ?? [];
    if (duplicateAccounts.isNotEmpty) {
      alerts.add(DashboardAlert(
        type: AlertType.warning,
        title: 'Duplicate Accounts',
        message: '${duplicateAccounts.length} potential duplicate accounts found',
        priority: AlertPriority.medium,
      ));
    }

    // Check system health
    final systemHealth = data.realtimeStatus['systemHealth'] as String? ?? 'unknown';
    if (systemHealth != 'healthy') {
      alerts.add(DashboardAlert(
        type: AlertType.error,
        title: 'System Health Issue',
        message: 'System health status: $systemHealth',
        priority: AlertPriority.high,
      ));
    }

    return alerts;
  }

  /// Get performance insights
  List<PerformanceInsight> getPerformanceInsights() {
    final insights = <PerformanceInsight>[];
    final data = _dashboardData.value;
    
    if (data == null) return insights;

    // Sales performance insight
    final monthlyTotal = data.salesSummary['monthlyTotal'] as double? ?? 0.0;
    final weeklyTotal = data.salesSummary['weeklyTotal'] as double? ?? 0.0;
    
    if (weeklyTotal > 0) {
      final weeklyProjection = weeklyTotal * 4.33; // Approximate weeks in month
      final growthRate = ((weeklyProjection - monthlyTotal) / monthlyTotal * 100);
      
      insights.add(PerformanceInsight(
        category: 'Sales',
        title: 'Monthly Sales Projection',
        description: growthRate > 0 
            ? 'Sales trending ${growthRate.toStringAsFixed(1)}% above target'
            : 'Sales trending ${(-growthRate).toStringAsFixed(1)}% below target',
        trend: growthRate > 0 ? TrendDirection.up : TrendDirection.down,
        value: weeklyProjection,
      ));
    }

    // Visit compliance insight
    final complianceRate = data.visitCompliance['complianceRate'] as double? ?? 0.0;
    insights.add(PerformanceInsight(
      category: 'Visits',
      title: 'Visit Compliance',
      description: _getComplianceDescription(complianceRate),
      trend: complianceRate >= 85 ? TrendDirection.up : 
             complianceRate >= 70 ? TrendDirection.stable : TrendDirection.down,
      value: complianceRate,
    ));

    // Team performance insight
    final avgPerformance = data.teamMetrics['avgPerformanceScore'] as double? ?? 0.0;
    insights.add(PerformanceInsight(
      category: 'Team',
      title: 'Team Performance',
      description: _getPerformanceDescription(avgPerformance),
      trend: avgPerformance >= 80 ? TrendDirection.up : 
             avgPerformance >= 60 ? TrendDirection.stable : TrendDirection.down,
      value: avgPerformance,
    ));

    return insights;
  }

  /// Get compliance description
  String _getComplianceDescription(double rate) {
    if (rate >= 90) return 'Excellent compliance rate';
    if (rate >= 80) return 'Good compliance rate';
    if (rate >= 70) return 'Acceptable compliance rate';
    return 'Compliance rate needs improvement';
  }

  /// Get performance description
  String _getPerformanceDescription(double score) {
    if (score >= 90) return 'Outstanding team performance';
    if (score >= 80) return 'Strong team performance';
    if (score >= 70) return 'Good team performance';
    if (score >= 60) return 'Average team performance';
    return 'Team performance needs attention';
  }

  /// Get key metrics summary
  Map<String, dynamic> getKeyMetricsSummary() {
    final data = _dashboardData.value;
    if (data == null) return {};

    return {
      'todaySales': data.salesSummary['dailyTotal'] ?? 0.0,
      'todayOrders': data.salesSummary['dailyOrders'] ?? 0,
      'visitCompliance': data.visitCompliance['complianceRate'] ?? 0.0,
      'activeReps': data.teamMetrics['activeReps'] ?? 0,
      'pendingOrders': data.realtimeStatus['pendingOrders'] ?? 0,
      'systemHealth': data.realtimeStatus['systemHealth'] ?? 'unknown',
    };
  }

  /// Get team performance ranking
  List<Map<String, dynamic>> getTeamPerformanceRanking() {
    final data = _dashboardData.value;
    if (data == null) return [];

    final repPerformance = data.teamMetrics['repPerformance'] as List? ?? [];
    
    // Sort by performance score
    repPerformance.sort((a, b) => 
      (b['performanceScore'] as double? ?? 0.0).compareTo(
        a['performanceScore'] as double? ?? 0.0
      )
    );

    return List<Map<String, dynamic>>.from(repPerformance);
  }

  /// Identify duplicate accounts
  Future<List<DuplicateAccountGroup>> identifyDuplicateAccounts() async {
    try {
      final duplicates = await ApiService.findDuplicateAccounts();
      return duplicates.map((dup) => DuplicateAccountGroup.fromJson(dup)).toList();
    } catch (e) {
      print('Error identifying duplicate accounts: $e');
      return [];
    }
  }

  /// Generate unique customer codes for accounts without codes
  Future<bool> generateUniqueCustomerCodes() async {
    try {
      final success = await ApiService.generateUniqueCustomerCodes();
      
      if (success) {
        // Refresh dashboard to reflect changes
        await _updateDashboard();
      }
      
      return success;
    } catch (e) {
      print('Error generating unique customer codes: $e');
      return false;
    }
  }

  /// Get export data for reporting
  Map<String, dynamic> getExportData() {
    final data = _dashboardData.value;
    if (data == null) return {};

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'dashboardData': data.toJson(),
      'alerts': getDashboardAlerts().map((alert) => alert.toJson()).toList(),
      'insights': getPerformanceInsights().map((insight) => insight.toJson()).toList(),
      'summary': getKeyMetricsSummary(),
    };
  }
}

class ManagerDashboardData {
  final Map<String, dynamic> salesSummary;
  final Map<String, dynamic> visitCompliance;
  final Map<String, dynamic> performanceTrends;
  final Map<String, dynamic> teamMetrics;
  final Map<String, dynamic> realtimeStatus;
  final Map<String, dynamic> accountMasterData;
  final DateTime lastUpdated;

  ManagerDashboardData({
    required this.salesSummary,
    required this.visitCompliance,
    required this.performanceTrends,
    required this.teamMetrics,
    required this.realtimeStatus,
    required this.accountMasterData,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'salesSummary': salesSummary,
      'visitCompliance': visitCompliance,
      'performanceTrends': performanceTrends,
      'teamMetrics': teamMetrics,
      'realtimeStatus': realtimeStatus,
      'accountMasterData': accountMasterData,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ManagerDashboardData.fromJson(Map<String, dynamic> json) {
    return ManagerDashboardData(
      salesSummary: Map<String, dynamic>.from(json['salesSummary'] ?? {}),
      visitCompliance: Map<String, dynamic>.from(json['visitCompliance'] ?? {}),
      performanceTrends: Map<String, dynamic>.from(json['performanceTrends'] ?? {}),
      teamMetrics: Map<String, dynamic>.from(json['teamMetrics'] ?? {}),
      realtimeStatus: Map<String, dynamic>.from(json['realtimeStatus'] ?? {}),
      accountMasterData: Map<String, dynamic>.from(json['accountMasterData'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class DashboardAlert {
  final AlertType type;
  final String title;
  final String message;
  final AlertPriority priority;

  DashboardAlert({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'title': title,
      'message': message,
      'priority': priority.toString(),
    };
  }
}

class PerformanceInsight {
  final String category;
  final String title;
  final String description;
  final TrendDirection trend;
  final double value;

  PerformanceInsight({
    required this.category,
    required this.title,
    required this.description,
    required this.trend,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'description': description,
      'trend': trend.toString(),
      'value': value,
    };
  }
}

class DuplicateAccountGroup {
  final List<int> accountIds;
  final String reason;
  final double confidence;

  DuplicateAccountGroup({
    required this.accountIds,
    required this.reason,
    required this.confidence,
  });

  factory DuplicateAccountGroup.fromJson(Map<String, dynamic> json) {
    return DuplicateAccountGroup(
      accountIds: List<int>.from(json['accountIds'] ?? []),
      reason: json['reason'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

enum AlertType {
  info,
  warning,
  error,
}

enum AlertPriority {
  low,
  medium,
  high,
  critical,
}

enum TrendDirection {
  up,
  down,
  stable,
}