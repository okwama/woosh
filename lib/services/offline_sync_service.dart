import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';
import 'package:woosh/services/hive/product_report_hive_service.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/hive/pending_session_model.dart';
import 'package:woosh/services/clockInOut/clock_in_out_service.dart';

class OfflineSyncService extends GetxService {
  static OfflineSyncService get instance => Get.find<OfflineSyncService>();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;

  // Services
  late PendingJourneyPlanHiveService _pendingJourneyPlanService;
  late PendingSessionHiveService _pendingSessionService;
  late ProductReportHiveService _productReportService;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeServices();
    _startConnectivityMonitoring();
  }

  Future<void> _initializeServices() async {
    try {
      _pendingJourneyPlanService = Get.find<PendingJourneyPlanHiveService>();
    } catch (e) {
      _pendingJourneyPlanService = PendingJourneyPlanHiveService();
      await _pendingJourneyPlanService.init();
      Get.put(_pendingJourneyPlanService);
    }

    try {
      _pendingSessionService = Get.find<PendingSessionHiveService>();
    } catch (e) {
      _pendingSessionService = PendingSessionHiveService();
      await _pendingSessionService.init();
      Get.put(_pendingSessionService);
    }

    try {
      _productReportService = Get.find<ProductReportHiveService>();
      // Ensure the service is properly initialized even if found
      // Check if the box is initialized by trying to access it safely
      try {
        // This will throw if the box is not initialized
        _productReportService.getUnsyncedReports();
      } catch (e) {
        // If the box is not initialized, reinitialize the service
        print(
            '⚠️ ProductReportHiveService box not initialized, reinitializing...');
        _productReportService = ProductReportHiveService();
        await _productReportService.init();
        Get.put(_productReportService);
      }
        } catch (e) {
      print('⚠️ ProductReportHiveService not found, initializing...');
      _productReportService = ProductReportHiveService();
      await _productReportService.init();
      Get.put(_productReportService);
    }
  }

  void _startConnectivityMonitoring() {
    // Check initial connectivity state
    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      print(
          '?? Initial connectivity status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

      // If we're online and have pending operations, start syncing immediately
      if (_isOnline && hasPendingOperations() && !_isSyncing) {
        print(
            '?? Device is online with pending operations - starting immediate sync...');
        _syncPendingOperations();
      }
    });

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasOffline = !_isOnline;
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      print(
          '?? Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"} (was ${wasOffline ? "OFFLINE" : "ONLINE"})');

      // If we just came back online, start syncing
      if (wasOffline && _isOnline && !_isSyncing) {
        _syncPendingOperations();
      }
    });
  }

  Future<void> _syncPendingOperations() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    // Log current pending operations
    final pendingCounts = getPendingOperationsCount();

    try {
      // Sync in order of priority:
      // 1. Session operations (most critical for user state)
      // 2. Journey plan creation
      // 3. Product reports

      await _syncPendingSessions();

      await _syncPendingJourneyPlans();

      await _syncPendingReports();

      final finalCounts = getPendingOperationsCount();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncPendingSessions() async {
    final pendingSessions = _pendingSessionService
        .getAllPendingSessions()
        .where((session) => session.status == 'pending')
        .toList();

    if (pendingSessions.isEmpty) return;

    for (final sessionData in pendingSessions) {
      try {
        await _pendingSessionService.updatePendingSessionStatus(
            sessionData.key.toString(), 'syncing');

        if (sessionData.operation == 'start') {
          await ClockInOutService.clockIn(sessionData.userId);
        } else if (sessionData.operation == 'end') {
          await ClockInOutService.clockOut(sessionData.userId);
        }

        // Remove successfully synced session
        await _pendingSessionService
            .deletePendingSession(sessionData.key.toString());
      } catch (e) {
        // Check if it's a server error
        if (e.toString().contains('500') ||
            e.toString().contains('501') ||
            e.toString().contains('502') ||
            e.toString().contains('503')) {
          // Mark as pending to retry later
          await _pendingSessionService.updatePendingSessionStatus(
              sessionData.key.toString(), 'pending',
              errorMessage: 'Server error - will retry');
        } else {
          // Handle specific cases that shouldn't be retried
          if (e.toString().contains('No active session found') ||
              e.toString().contains('Sessions can only be started from') ||
              e.toString().contains('Session already active')) {
            // These are validation errors that won't succeed on retry
            await _pendingSessionService
                .deletePendingSession(sessionData.key.toString());
          } else {
            // Mark as error for other failures and retry
            final retryCount = sessionData.retryCount + 1;
            if (retryCount >= 3) {
              // Max retries reached, delete
              await _pendingSessionService
                  .deletePendingSession(sessionData.key.toString());
            } else {
              await _pendingSessionService.updatePendingSessionStatus(
                  sessionData.key.toString(), 'error',
                  errorMessage: e.toString(), retryCount: retryCount);
            }
          }
        }
      }
    }
  }

  Future<void> _syncPendingJourneyPlans() async {
    final pendingPlans =
        _pendingJourneyPlanService.getAllPendingJourneyPlansWithIds();
    final pendingEntries = pendingPlans.entries
        .where((entry) => entry.value.status == 'pending')
        .toList();

    if (pendingEntries.isEmpty) return;

    for (final entry in pendingEntries) {
      try {
        await _pendingJourneyPlanService.updatePendingJourneyPlanStatus(
            entry.key, 'syncing');

        final plan = entry.value;
        await JourneyPlanService.createJourneyPlan(
          plan.clientId,
          plan.date,
          notes: plan.notes,
          routeId: plan.routeId,
        );

        // Remove successfully synced plan
        await _pendingJourneyPlanService.deletePendingJourneyPlan(entry.key);
      } catch (e) {
        // Check if it's a server error
        if (e.toString().contains('500') ||
            e.toString().contains('501') ||
            e.toString().contains('502') ||
            e.toString().contains('503')) {
          // Mark as pending to retry later
          await _pendingJourneyPlanService.updatePendingJourneyPlanStatus(
              entry.key, 'pending',
              errorMessage: 'Server error - will retry');
        } else {
          // Mark as error for other failures
          await _pendingJourneyPlanService.updatePendingJourneyPlanStatus(
              entry.key, 'error',
              errorMessage: e.toString());
        }
      }
    }
  }

  Future<void> _syncPendingReports() async {
    final unsyncedReports = _productReportService.getUnsyncedReports();

    if (unsyncedReports.isEmpty) return;

    for (final reportData in unsyncedReports) {
      try {
        // Convert to API format and submit
        final salesRepId = ApiService.getCurrentUserId();
        if (salesRepId == null) {
          continue;
        }
        final report =
            _productReportService.convertToReportModel(reportData, salesRepId);

        await ApiService().submitReport(report);

        // Mark as synced
        await _productReportService.markAsSynced(reportData.journeyPlanId);
      } catch (e) {
        // Reports will remain unsynced and retry on next connection
      }
    }
  }

  // Manual sync trigger
  Future<void> forcSync() async {
    if (!_isOnline) {
      return;
    }

    await _syncPendingOperations();
  }

  // Check if there are pending operations
  bool hasPendingOperations() {
    final pendingSessions = _pendingSessionService
        .getAllPendingSessions()
        .where((session) => session.status == 'pending')
        .length;

    final pendingPlans = _pendingJourneyPlanService
        .getAllPendingJourneyPlans()
        .where((plan) => plan.status == 'pending')
        .length;

    final pendingReports = _productReportService.getUnsyncedReports().length;

    return pendingSessions > 0 || pendingPlans > 0 || pendingReports > 0;
  }

  // Get pending operations count
  Map<String, int> getPendingOperationsCount() {
    return {
      'sessions': _pendingSessionService
          .getAllPendingSessions()
          .where((session) => session.status == 'pending')
          .length,
      'journeyPlans': _pendingJourneyPlanService
          .getAllPendingJourneyPlans()
          .where((plan) => plan.status == 'pending')
          .length,
      'reports': _productReportService.getUnsyncedReports().length,
    };
  }

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
