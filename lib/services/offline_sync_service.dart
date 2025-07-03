import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';
import 'package:woosh/services/hive/product_report_hive_service.dart';
import 'package:woosh/services/jouneyplan_service.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/hive/pending_session_model.dart';

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
    } catch (e) {
      _productReportService = ProductReportHiveService();
      await _productReportService.init();
      Get.put(_productReportService);
    }
  }

  void _startConnectivityMonitoring() {
    print('🔄 Starting connectivity monitoring...');

    // Check initial connectivity state
    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      print(
          '📶 Initial connectivity status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

      // If we're online and have pending operations, start syncing immediately
      if (_isOnline && hasPendingOperations() && !_isSyncing) {
        print(
            '📶 Device is online with pending operations - starting immediate sync...');
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
          '📶 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"} (was ${wasOffline ? "OFFLINE" : "ONLINE"})');

      // If we just came back online, start syncing
      if (wasOffline && _isOnline && !_isSyncing) {
        print('📶 Connection restored - starting sync...');
        _syncPendingOperations();
      }
    });
  }

  Future<void> _syncPendingOperations() async {
    if (_isSyncing) {
      print('🔄 Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    print('🔄 Starting offline sync...');

    // Log current pending operations
    final pendingCounts = getPendingOperationsCount();
    print('📦 Pending operations: $pendingCounts');

    try {
      // Sync in order of priority:
      // 1. Session operations (most critical for user state)
      // 2. Journey plan creation
      // 3. Product reports

      print('🔄 Step 1: Syncing pending sessions...');
      await _syncPendingSessions();

      print('🔄 Step 2: Syncing pending journey plans...');
      await _syncPendingJourneyPlans();

      print('🔄 Step 3: Syncing pending reports...');
      await _syncPendingReports();

      final finalCounts = getPendingOperationsCount();
      print('✅ Offline sync completed successfully');
      print('📦 Remaining operations: $finalCounts');
    } catch (e) {
      print('❌ Error during offline sync: $e');
    } finally {
      _isSyncing = false;
      print('🔄 Sync process ended');
    }
  }

  Future<void> _syncPendingSessions() async {
    final pendingSessions = _pendingSessionService
        .getAllPendingSessions()
        .where((session) => session.status == 'pending')
        .toList();

    if (pendingSessions.isEmpty) return;

    print('🔄 Syncing ${pendingSessions.length} pending session operations...');

    for (final sessionData in pendingSessions) {
      try {
        await _pendingSessionService.updatePendingSessionStatus(
            sessionData.key.toString(), 'syncing');

        if (sessionData.operation == 'start') {
          await SessionService.recordLogin(sessionData.userId);
          print('✅ Synced session start for user ${sessionData.userId}');
        } else if (sessionData.operation == 'end') {
          await SessionService.recordLogout(sessionData.userId);
          print('✅ Synced session end for user ${sessionData.userId}');
        }

        // Remove successfully synced session
        await _pendingSessionService
            .deletePendingSession(sessionData.key.toString());
      } catch (e) {
        print('❌ Failed to sync session operation: $e');

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
            print('🗑️ Deleted session operation due to validation error: $e');
          } else {
            // Mark as error for other failures and retry
            final retryCount = sessionData.retryCount + 1;
            if (retryCount >= 3) {
              // Max retries reached, delete
              await _pendingSessionService
                  .deletePendingSession(sessionData.key.toString());
              print('🗑️ Deleted session operation after max retries');
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

    print('🔄 Syncing ${pendingEntries.length} pending journey plans...');

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

        print('✅ Synced journey plan for client ${plan.clientId}');

        // Remove successfully synced plan
        await _pendingJourneyPlanService.deletePendingJourneyPlan(entry.key);
      } catch (e) {
        print('❌ Failed to sync journey plan: $e');

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

    print('🔄 Syncing ${unsyncedReports.length} pending reports...');

    for (final reportData in unsyncedReports) {
      try {
        // Convert to API format and submit
        final salesRepId = ApiService.getCurrentUserId();
        if (salesRepId == null) {
          print('❌ Cannot sync report - user ID not found');
          continue;
        }
        final report =
            _productReportService.convertToReportModel(reportData, salesRepId);

        await ApiService().submitReport(report);

        print('✅ Synced report for journey plan ${reportData.journeyPlanId}');

        // Mark as synced
        await _productReportService.markAsSynced(reportData.journeyPlanId);
      } catch (e) {
        print('❌ Failed to sync report: $e');
        // Reports will remain unsynced and retry on next connection
      }
    }
  }

  // Manual sync trigger
  Future<void> forcSync() async {
    print('🔄 Force sync requested...');
    print('📶 Online status: ${_isOnline}');
    print('🔄 Currently syncing: ${_isSyncing}');
    print('📦 Has pending operations: ${hasPendingOperations()}');

    if (!_isOnline) {
      print('📵 Cannot sync - device is offline');
      return;
    }

    print('🚀 Starting manual sync...');
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
