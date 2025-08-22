import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:get_storage/get_storage.dart';

class DailyActivityReportService extends GetxService {
  static DailyActivityReportService get instance => Get.find<DailyActivityReportService>();

  final GetStorage _storage = GetStorage();
  
  // Observable report data
  final Rx<DailyActivityReport?> _todayReport = Rx<DailyActivityReport?>(null);
  final RxBool _isGenerating = false.obs;

  DailyActivityReport? get todayReport => _todayReport.value;
  bool get isGenerating => _isGenerating.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadTodayReport();
  }

  /// Load today's activity report
  Future<void> _loadTodayReport() async {
    try {
      _isGenerating.value = true;
      final report = await generateDailyReport(DateTime.now());
      _todayReport.value = report;
    } catch (e) {
      print('Error loading today\'s report: $e');
    } finally {
      _isGenerating.value = false;
    }
  }

  /// Generate daily activity report for specific date
  Future<DailyActivityReport> generateDailyReport(DateTime date) async {
    try {
      _isGenerating.value = true;
      
      final dateStr = _formatDate(date);
      
      // Fetch all data for the day in parallel
      final results = await Future.wait([
        _getJourneyPlansForDate(date),
        _getOrdersForDate(date),
        _getSessionDataForDate(date),
        _getPerformanceMetricsForDate(date),
      ]);

      final journeyPlans = results[0] as List<JourneyPlan>;
      final orders = results[1] as List<Order>;
      final sessionData = results[2] as Map<String, dynamic>;
      final performanceMetrics = results[3] as Map<String, dynamic>;

      // Generate comprehensive report
      final report = DailyActivityReport(
        date: date,
        journeyPlans: journeyPlans,
        orders: orders,
        sessionData: sessionData,
        performanceMetrics: performanceMetrics,
        generatedAt: DateTime.now(),
      );

      // Cache the report
      await _cacheReport(report);
      
      return report;
      
    } catch (e) {
      print('Error generating daily report: $e');
      throw Exception('Failed to generate daily report');
    } finally {
      _isGenerating.value = false;
    }
  }

  /// Get journey plans for specific date
  Future<List<JourneyPlan>> _getJourneyPlansForDate(DateTime date) async {
    try {
      return await JourneyPlanService.getJourneyPlansByDate(date);
    } catch (e) {
      print('Error fetching journey plans for date: $e');
      return [];
    }
  }

  /// Get orders for specific date
  Future<List<Order>> _getOrdersForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));
      
      return await ApiService.getOrdersInDateRange(
        startDate: startOfDay,
        endDate: endOfDay,
      );
    } catch (e) {
      print('Error fetching orders for date: $e');
      return [];
    }
  }

  /// Get session data for specific date
  Future<Map<String, dynamic>> _getSessionDataForDate(DateTime date) async {
    try {
      // This would fetch session/clock-in data from your API
      // For now, return basic structure
      return {
        'clockInTime': null,
        'clockOutTime': null,
        'totalHours': 0.0,
        'status': 'unknown',
      };
    } catch (e) {
      print('Error fetching session data for date: $e');
      return {};
    }
  }

  /// Get performance metrics for specific date
  Future<Map<String, dynamic>> _getPerformanceMetricsForDate(DateTime date) async {
    try {
      // This would fetch performance metrics
      return {
        'totalDistance': 0.0,
        'averageVisitDuration': 0.0,
        'successfulVisits': 0,
        'totalVisits': 0,
      };
    } catch (e) {
      print('Error fetching performance metrics for date: $e');
      return {};
    }
  }

  /// Cache report for offline access
  Future<void> _cacheReport(DailyActivityReport report) async {
    try {
      final dateKey = _formatDate(report.date);
      final reportData = report.toJson();
      
      final cachedReports = _storage.read<Map>('cached_reports') ?? {};
      cachedReports[dateKey] = reportData;
      
      // Keep only last 30 days of reports
      final cutoffDate = DateTime.now().subtract(Duration(days: 30));
      cachedReports.removeWhere((key, value) {
        try {
          final reportDate = DateTime.parse(key);
          return reportDate.isBefore(cutoffDate);
        } catch (e) {
          return true; // Remove invalid entries
        }
      });
      
      await _storage.write('cached_reports', cachedReports);
      
    } catch (e) {
      print('Error caching report: $e');
    }
  }

  /// Get cached report for date
  DailyActivityReport? getCachedReport(DateTime date) {
    try {
      final dateKey = _formatDate(date);
      final cachedReports = _storage.read<Map>('cached_reports') ?? {};
      final reportData = cachedReports[dateKey];
      
      if (reportData != null) {
        return DailyActivityReport.fromJson(reportData);
      }
      
      return null;
    } catch (e) {
      print('Error getting cached report: $e');
      return null;
    }
  }

  /// Get report summary for quick view
  Map<String, dynamic> getReportSummary(DateTime date) {
    final report = _todayReport.value;
    if (report == null || !_isSameDate(report.date, date)) {
      return {'error': 'No report available for this date'};
    }

    return {
      'date': _formatDate(date),
      'totalVisits': report.journeyPlans.length,
      'completedVisits': report.journeyPlans.where((jp) => jp.isCompleted).length,
      'totalOrders': report.orders.length,
      'orderValue': report.orders.fold<double>(0, (sum, order) => sum + (order.totalAmount ?? 0)),
      'workingHours': report.sessionData['totalHours'] ?? 0.0,
      'generatedAt': report.generatedAt.toIso8601String(),
    };
  }

  /// Get available report dates (last 30 days)
  List<DateTime> getAvailableReportDates() {
    final dates = <DateTime>[];
    final today = DateTime.now();
    
    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      dates.add(DateTime(date.year, date.month, date.day));
    }
    
    return dates;
  }

  /// Check if report exists for date
  bool hasReportForDate(DateTime date) {
    final dateKey = _formatDate(date);
    final cachedReports = _storage.read<Map>('cached_reports') ?? {};
    return cachedReports.containsKey(dateKey);
  }

  /// Submit daily report (mark as submitted)
  Future<bool> submitDailyReport(DateTime date, {String? notes}) async {
    try {
      final report = await generateDailyReport(date);
      
      // Submit to backend
      final success = await _submitReportToBackend(report, notes);
      
      if (success) {
        // Mark as submitted locally
        await _markReportAsSubmitted(date);
        
        Get.snackbar(
          'Report Submitted',
          'Daily activity report has been submitted successfully.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
      
      return success;
      
    } catch (e) {
      print('Error submitting daily report: $e');
      
      Get.snackbar(
        'Submission Failed',
        'Failed to submit daily report. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return false;
    }
  }

  /// Submit report to backend
  Future<bool> _submitReportToBackend(DailyActivityReport report, String? notes) async {
    try {
      final reportData = {
        'date': _formatDate(report.date),
        'summary': report.getSummary(),
        'details': report.toJson(),
        'notes': notes,
        'submittedAt': DateTime.now().toIso8601String(),
      };
      
      // This would call your actual report submission API
      // await ApiService.submitDailyReport(reportData);
      
      return true; // Simulate success for now
      
    } catch (e) {
      print('Error submitting report to backend: $e');
      return false;
    }
  }

  /// Mark report as submitted
  Future<void> _markReportAsSubmitted(DateTime date) async {
    final dateKey = _formatDate(date);
    final submittedReports = _storage.read<List>('submitted_reports') ?? [];
    
    if (!submittedReports.contains(dateKey)) {
      submittedReports.add(dateKey);
      await _storage.write('submitted_reports', submittedReports);
    }
  }

  /// Check if report is submitted
  bool isReportSubmitted(DateTime date) {
    final dateKey = _formatDate(date);
    final submittedReports = _storage.read<List>('submitted_reports') ?? [];
    return submittedReports.contains(dateKey);
  }

  /// Format date as string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if two dates are the same day
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Refresh today's report
  Future<void> refreshTodayReport() async {
    await _loadTodayReport();
  }

  /// Export report data (for sharing or backup)
  Map<String, dynamic> exportReportData(DateTime date) {
    final report = getCachedReport(date);
    if (report == null) {
      throw Exception('No report available for the specified date');
    }
    
    return {
      'report': report.toJson(),
      'summary': report.getSummary(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}

class DailyActivityReport {
  final DateTime date;
  final List<JourneyPlan> journeyPlans;
  final List<Order> orders;
  final Map<String, dynamic> sessionData;
  final Map<String, dynamic> performanceMetrics;
  final DateTime generatedAt;

  DailyActivityReport({
    required this.date,
    required this.journeyPlans,
    required this.orders,
    required this.sessionData,
    required this.performanceMetrics,
    required this.generatedAt,
  });

  /// Get report summary
  Map<String, dynamic> getSummary() {
    final completedVisits = journeyPlans.where((jp) => jp.isCompleted).length;
    final totalOrderValue = orders.fold<double>(0, (sum, order) => sum + (order.totalAmount ?? 0));
    
    return {
      'date': date.toIso8601String().split('T')[0],
      'totalVisits': journeyPlans.length,
      'completedVisits': completedVisits,
      'visitCompletionRate': journeyPlans.isNotEmpty 
          ? (completedVisits / journeyPlans.length * 100).toStringAsFixed(1)
          : '0.0',
      'totalOrders': orders.length,
      'totalOrderValue': totalOrderValue,
      'averageOrderValue': orders.isNotEmpty 
          ? (totalOrderValue / orders.length).toStringAsFixed(2)
          : '0.00',
      'workingHours': sessionData['totalHours'] ?? 0.0,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  /// Get detailed visit breakdown
  Map<String, dynamic> getVisitBreakdown() {
    final completed = journeyPlans.where((jp) => jp.isCompleted).length;
    final pending = journeyPlans.where((jp) => jp.isPending).length;
    final cancelled = journeyPlans.where((jp) => jp.isCancelled).length;
    final inProgress = journeyPlans.where((jp) => jp.isInProgress).length;
    
    return {
      'completed': completed,
      'pending': pending,
      'cancelled': cancelled,
      'inProgress': inProgress,
      'total': journeyPlans.length,
    };
  }

  /// Get order breakdown by status
  Map<String, dynamic> getOrderBreakdown() {
    final statusCounts = <String, int>{};
    double totalValue = 0.0;
    
    for (final order in orders) {
      final status = order.status.toString();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      totalValue += order.totalAmount ?? 0.0;
    }
    
    return {
      'statusBreakdown': statusCounts,
      'totalValue': totalValue,
      'averageValue': orders.isNotEmpty ? totalValue / orders.length : 0.0,
      'totalCount': orders.length,
    };
  }

  /// Get performance insights
  Map<String, dynamic> getPerformanceInsights() {
    final visitBreakdown = getVisitBreakdown();
    final orderBreakdown = getOrderBreakdown();
    
    final insights = <String, dynamic>{};
    
    // Visit completion rate insight
    final completionRate = visitBreakdown['total'] > 0 
        ? (visitBreakdown['completed'] / visitBreakdown['total'] * 100)
        : 0.0;
    
    if (completionRate >= 90) {
      insights['visitPerformance'] = 'Excellent visit completion rate!';
    } else if (completionRate >= 70) {
      insights['visitPerformance'] = 'Good visit completion rate.';
    } else {
      insights['visitPerformance'] = 'Visit completion rate needs improvement.';
    }

    // Order performance insight
    final avgOrderValue = orderBreakdown['averageValue'] as double;
    if (avgOrderValue > 1000) {
      insights['orderPerformance'] = 'Strong order values achieved today!';
    } else if (avgOrderValue > 500) {
      insights['orderPerformance'] = 'Moderate order performance.';
    } else {
      insights['orderPerformance'] = 'Focus on increasing order values.';
    }

    // Working hours insight
    final workingHours = sessionData['totalHours'] as double? ?? 0.0;
    if (workingHours >= 8) {
      insights['timeManagement'] = 'Full working day completed.';
    } else if (workingHours >= 6) {
      insights['timeManagement'] = 'Good working hours.';
    } else {
      insights['timeManagement'] = 'Consider optimizing time management.';
    }

    return insights;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'journeyPlans': journeyPlans.map((jp) => jp.toJson()).toList(),
      'orders': orders.map((order) => order.toJson()).toList(),
      'sessionData': sessionData,
      'performanceMetrics': performanceMetrics,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory DailyActivityReport.fromJson(Map<String, dynamic> json) {
    return DailyActivityReport(
      date: DateTime.parse(json['date']),
      journeyPlans: (json['journeyPlans'] as List)
          .map((jp) => JourneyPlan.fromJson(jp))
          .toList(),
      orders: (json['orders'] as List)
          .map((order) => Order.fromJson(order))
          .toList(),
      sessionData: Map<String, dynamic>.from(json['sessionData']),
      performanceMetrics: Map<String, dynamic>.from(json['performanceMetrics']),
      generatedAt: DateTime.parse(json['generatedAt']),
    );
  }

  /// Format date as string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}