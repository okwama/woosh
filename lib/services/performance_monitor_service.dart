import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PerformanceMonitorService extends GetxService {
  static PerformanceMonitorService get instance => Get.find<PerformanceMonitorService>();

  final GetStorage _storage = GetStorage();
  final Map<String, Stopwatch> _activeOperations = {};
  final List<PerformanceMetric> _metrics = [];
  Timer? _reportTimer;

  // Performance thresholds (in milliseconds)
  static const int slowLoginThreshold = 5000; // 5 seconds
  static const int slowNavigationThreshold = 2000; // 2 seconds
  static const int slowApiThreshold = 3000; // 3 seconds
  static const int crashDetectionInterval = 30000; // 30 seconds

  @override
  Future<void> onInit() async {
    super.onInit();
    _loadStoredMetrics();
    _startPerformanceReporting();
    _detectAppCrashes();
  }

  @override
  void onClose() {
    _reportTimer?.cancel();
    _saveMetrics();
    super.onClose();
  }

  /// Start tracking an operation
  void startOperation(String operationId, String operationType) {
    final stopwatch = Stopwatch()..start();
    _activeOperations[operationId] = stopwatch;
    
    if (kDebugMode) {
      print('🚀 Started tracking: $operationType ($operationId)');
    }
  }

  /// End tracking an operation and record metrics
  void endOperation(String operationId, String operationType, {
    bool wasSuccessful = true,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = _activeOperations.remove(operationId);
    if (stopwatch == null) return;

    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    final metric = PerformanceMetric(
      operationType: operationType,
      operationId: operationId,
      duration: duration,
      timestamp: DateTime.now(),
      wasSuccessful: wasSuccessful,
      errorMessage: errorMessage,
      metadata: metadata,
    );

    _metrics.add(metric);
    _analyzePerformance(metric);

    if (kDebugMode) {
      print('⏱️ Completed: $operationType ($operationId) - ${duration}ms');
    }

    // Keep only last 100 metrics to prevent memory issues
    if (_metrics.length > 100) {
      _metrics.removeRange(0, _metrics.length - 100);
    }
  }

  /// Analyze performance and provide feedback
  void _analyzePerformance(PerformanceMetric metric) {
    bool isSlowOperation = false;
    String? suggestion;

    switch (metric.operationType) {
      case 'login':
        if (metric.duration > slowLoginThreshold) {
          isSlowOperation = true;
          suggestion = 'Login is taking longer than expected. Check network connection.';
        }
        break;
      case 'navigation':
        if (metric.duration > slowNavigationThreshold) {
          isSlowOperation = true;
          suggestion = 'Page navigation is slow. Consider implementing lazy loading.';
        }
        break;
      case 'api_call':
        if (metric.duration > slowApiThreshold) {
          isSlowOperation = true;
          suggestion = 'API call is slow. Check network connection or server performance.';
        }
        break;
    }

    if (isSlowOperation && suggestion != null) {
      _recordPerformanceIssue(metric, suggestion);
    }
  }

  /// Record performance issue
  void _recordPerformanceIssue(PerformanceMetric metric, String suggestion) {
    if (kDebugMode) {
      print('⚠️ Performance Issue: ${metric.operationType} took ${metric.duration}ms');
      print('💡 Suggestion: $suggestion');
    }

    // Store performance issues for reporting
    final issues = _storage.read<List>('performance_issues') ?? [];
    issues.add({
      'type': metric.operationType,
      'duration': metric.duration,
      'timestamp': metric.timestamp.toIso8601String(),
      'suggestion': suggestion,
      'metadata': metric.metadata,
    });

    // Keep only last 50 issues
    if (issues.length > 50) {
      issues.removeRange(0, issues.length - 50);
    }

    _storage.write('performance_issues', issues);
  }

  /// Detect app crashes by monitoring unexpected shutdowns
  void _detectAppCrashes() {
    // Mark app as running
    _storage.write('app_running', true);
    _storage.write('last_heartbeat', DateTime.now().toIso8601String());

    // Check if previous session ended unexpectedly
    final wasRunning = _storage.read<bool>('app_running') ?? false;
    if (wasRunning) {
      _recordCrash();
    }

    // Start heartbeat to detect crashes
    Timer.periodic(Duration(milliseconds: crashDetectionInterval), (_) {
      _storage.write('last_heartbeat', DateTime.now().toIso8601String());
    });
  }

  /// Record app crash
  void _recordCrash() {
    final crashes = _storage.read<List>('app_crashes') ?? [];
    crashes.add({
      'timestamp': DateTime.now().toIso8601String(),
      'last_heartbeat': _storage.read<String>('last_heartbeat'),
    });

    // Keep only last 10 crashes
    if (crashes.length > 10) {
      crashes.removeRange(0, crashes.length - 10);
    }

    _storage.write('app_crashes', crashes);
    
    if (kDebugMode) {
      print('💥 App crash detected and recorded');
    }
  }

  /// Start performance reporting
  void _startPerformanceReporting() {
    _reportTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _generatePerformanceReport();
    });
  }

  /// Generate performance report
  void _generatePerformanceReport() {
    if (_metrics.isEmpty) return;

    final recentMetrics = _metrics.where(
      (m) => DateTime.now().difference(m.timestamp).inMinutes <= 5,
    ).toList();

    if (recentMetrics.isEmpty) return;

    final report = _createPerformanceReport(recentMetrics);
    
    if (kDebugMode) {
      print('📊 Performance Report: $report');
    }
  }

  /// Create performance report
  Map<String, dynamic> _createPerformanceReport(List<PerformanceMetric> metrics) {
    final groupedMetrics = <String, List<PerformanceMetric>>{};
    
    for (final metric in metrics) {
      groupedMetrics.putIfAbsent(metric.operationType, () => []).add(metric);
    }

    final report = <String, dynamic>{};
    
    for (final entry in groupedMetrics.entries) {
      final operationType = entry.key;
      final operationMetrics = entry.value;
      
      final durations = operationMetrics.map((m) => m.duration).toList();
      final successfulOps = operationMetrics.where((m) => m.wasSuccessful).length;
      
      report[operationType] = {
        'count': operationMetrics.length,
        'avgDuration': durations.reduce((a, b) => a + b) / durations.length,
        'maxDuration': durations.reduce((a, b) => a > b ? a : b),
        'minDuration': durations.reduce((a, b) => a < b ? a : b),
        'successRate': (successfulOps / operationMetrics.length * 100).toStringAsFixed(1),
      };
    }

    return report;
  }

  /// Load stored metrics
  void _loadStoredMetrics() {
    final storedMetrics = _storage.read<List>('performance_metrics');
    if (storedMetrics != null) {
      for (final metricData in storedMetrics) {
        try {
          _metrics.add(PerformanceMetric.fromJson(metricData));
        } catch (e) {
          if (kDebugMode) {
            print('Error loading stored metric: $e');
          }
        }
      }
    }
  }

  /// Save metrics to storage
  void _saveMetrics() {
    final metricsToSave = _metrics.take(50).map((m) => m.toJson()).toList();
    _storage.write('performance_metrics', metricsToSave);
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    if (_metrics.isEmpty) {
      return {'message': 'No performance data available'};
    }

    return _createPerformanceReport(_metrics);
  }

  /// Get recent performance issues
  List<Map<String, dynamic>> getRecentIssues() {
    return List<Map<String, dynamic>>.from(
      _storage.read<List>('performance_issues') ?? []
    );
  }

  /// Get crash history
  List<Map<String, dynamic>> getCrashHistory() {
    return List<Map<String, dynamic>>.from(
      _storage.read<List>('app_crashes') ?? []
    );
  }

  /// Mark app shutdown as clean
  void markCleanShutdown() {
    _storage.write('app_running', false);
  }
}

class PerformanceMetric {
  final String operationType;
  final String operationId;
  final int duration;
  final DateTime timestamp;
  final bool wasSuccessful;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.operationType,
    required this.operationId,
    required this.duration,
    required this.timestamp,
    required this.wasSuccessful,
    this.errorMessage,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationType': operationType,
      'operationId': operationId,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'wasSuccessful': wasSuccessful,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      operationType: json['operationType'],
      operationId: json['operationId'],
      duration: json['duration'],
      timestamp: DateTime.parse(json['timestamp']),
      wasSuccessful: json['wasSuccessful'],
      errorMessage: json['errorMessage'],
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}