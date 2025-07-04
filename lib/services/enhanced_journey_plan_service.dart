import 'package:get/get.dart';
import 'package:woosh/services/jouneyplan_service.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/models/hive/pending_journey_plan_model.dart';
import 'package:woosh/models/journeyplan_model.dart';

class EnhancedJourneyPlanService {
  static late PendingJourneyPlanHiveService _pendingService;

  static Future<void> initialize() async {
    try {
      _pendingService = Get.find<PendingJourneyPlanHiveService>();
    } catch (e) {
      _pendingService = PendingJourneyPlanHiveService();
      await _pendingService.init();
      Get.put(_pendingService);
    }
  }

  /// Enhanced journey plan creation with offline support
  static Future<JourneyPlan?> createJourneyPlan(
    int clientId,
    DateTime dateTime, {
    String? notes,
    int? routeId,
  }) async {
    try {
      // Try to create via API first
      final journeyPlan = await JourneyPlanService.createJourneyPlan(
        clientId,
        dateTime,
        notes: notes,
        routeId: routeId,
      );

      print('? Journey plan created successfully (online)');
      return journeyPlan;
    } catch (e) {
      print('? Journey plan creation failed, checking if server error: $e');

      // Check if it's a server error (500-503)
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('?? Server error detected - saving journey plan for later sync');

        // Save pending journey plan operation
        await _savePendingJourneyPlan(clientId, dateTime,
            notes: notes, routeId: routeId);

        print(
            '?? Journey plan saved locally - will sync when server is available');

        // Return null to indicate offline save (caller should handle this)
        return null;
      } else {
        // Other errors (network, validation, etc.) - rethrow
        rethrow;
      }
    }
  }

  /// Save pending journey plan operation for later sync
  static Future<void> _savePendingJourneyPlan(
    int clientId,
    DateTime dateTime, {
    String? notes,
    int? routeId,
  }) async {
    final pendingPlan = PendingJourneyPlanModel(
      clientId: clientId,
      date: dateTime,
      notes: notes,
      routeId: routeId,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    await _pendingService.savePendingJourneyPlan(pendingPlan);
    print('?? Saved pending journey plan for client $clientId');
  }

  /// Get all pending journey plans
  static Future<List<PendingJourneyPlanModel>> getPendingJourneyPlans() async {
    return _pendingService
        .getAllPendingJourneyPlans()
        .where((plan) => plan.status == 'pending')
        .toList();
  }

  /// Get pending journey plans count
  static Future<int> getPendingJourneyPlansCount() async {
    return _pendingService
        .getAllPendingJourneyPlans()
        .where((plan) => plan.status == 'pending')
        .length;
  }

  /// Enhanced journey plan update with offline support for reports
  static Future<JourneyPlan> updateJourneyPlan({
    required int journeyId,
    required int clientId,
    int? status,
    DateTime? checkInTime,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? notes,
    DateTime? checkoutTime,
    double? checkoutLatitude,
    double? checkoutLongitude,
  }) async {
    try {
      // Try to update via API first
      return await JourneyPlanService.updateJourneyPlan(
        journeyId: journeyId,
        clientId: clientId,
        status: status,
        checkInTime: checkInTime,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
        notes: notes,
        checkoutTime: checkoutTime,
        checkoutLatitude: checkoutLatitude,
        checkoutLongitude: checkoutLongitude,
      );
    } catch (e) {
      print('? Journey plan update failed: $e');

      // Check if it's a server error (500-503)
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('?? Server error detected during journey plan update');

        // For journey plan updates (like check-in), we'll let the service handle retries
        // This is different from creation which we can defer
        rethrow;
      } else {
        // Other errors - rethrow
        rethrow;
      }
    }
  }

  /// Wrapper methods that use the original service but with enhanced error handling
  static Future<PaginatedJourneyPlanResponse> fetchJourneyPlans({
    int page = 1,
    int limit = 20,
    JourneyPlanStatus? status,
    String timezone = 'Africa/Nairobi',
  }) async {
    return await JourneyPlanService.fetchJourneyPlans(
      page: page,
      limit: limit,
      status: status,
      timezone: timezone,
    );
  }

  static Future<JourneyPlan?> getJourneyPlanById(int journeyId) async {
    return await JourneyPlanService.getJourneyPlanById(journeyId);
  }

  static Future<JourneyPlan?> getActiveVisit() async {
    return await JourneyPlanService.getActiveVisit();
  }

  static Future<void> deleteJourneyPlan(int journeyId) async {
    return await JourneyPlanService.deleteJourneyPlan(journeyId);
  }
}
