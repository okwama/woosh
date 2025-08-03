import 'package:get/get.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/services/client/client_service.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'dart:async';

/// Journey Plan State Service - Manages journey plan state across the app
///
/// This service prevents excessive API calls by:
/// - Centralizing journey plan data management
/// - Implementing proper caching
/// - Adding debouncing for refresh operations
/// - Managing loading states
class JourneyPlanStateService extends GetxController {
  // Observable variables
  final journeyPlans = <JourneyPlan>[].obs;
  final clients = <Client>[].obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final error = Rxn<String>();
  final selectedJourneyPlan = Rxn<JourneyPlan>();
  final currentPage = 1.obs;
  final hasMoreData = true.obs;
  final lastRefresh = Rxn<DateTime>();

  // Filters
  final selectedStatus = Rxn<String>();
  final selectedDate = Rxn<DateTime>();

  // Rate limiting for individual journey plan refreshes
  final Map<int, DateTime> _lastRefreshTimes = {};

  // Debouncing
  Timer? _debounceTimer;
  Timer? _refreshTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 1000);
  static const Duration _refreshInterval =
      Duration(minutes: 10); // Increased to reduce API calls

  // Cache settings
  static const Duration _cacheDuration = Duration(minutes: 10);

  @override
  void onInit() {
    super.onInit();
    _startPeriodicRefresh();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _refreshTimer?.cancel();
    super.onClose();
  }

  /// Start periodic refresh with longer interval
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (Get.isRegistered<JourneyPlanStateService>()) {
        _debouncedRefresh();
      }
    });
  }

  /// Debounced refresh to prevent excessive calls
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!isRefreshing.value && !isLoading.value) {
        _refreshData();
      }
    });
  }

  /// Check if cached data is still valid
  bool _shouldUseCachedData() {
    if (journeyPlans.isEmpty) return false;
    if (lastRefresh.value == null) return false;

    final now = DateTime.now();
    final lastUpdate = lastRefresh.value!;
    final difference = now.difference(lastUpdate);

    return difference < _cacheDuration;
  }

  /// Load journey plans with caching
  Future<void> loadJourneyPlans({
    bool forceRefresh = false,
    int page = 1,
    String? status,
    DateTime? date,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh && _shouldUseCachedData()) {
        print('📋 Using cached journey plans');
        return;
      }

      isLoading.value = true;
      error.value = null;

      print('📋 Loading journey plans...');

      // Fetch journey plans and clients in parallel
      final journeyPlansFuture = JourneyPlanService.fetchJourneyPlans(
        page: page,
        status: status != null ? _parseStatus(status) : null,
      );

      final routeId = await _getCurrentUserRouteId();
      final clientsFuture = ClientService.fetchClients(routeId: routeId);

      // Await both futures
      final journeyPlansResult = await journeyPlansFuture;
      final clientsResult = await clientsFuture;

      final List<JourneyPlan> fetchedPlans = journeyPlansResult.data;
      final List<dynamic> clientData = clientsResult['data'] ?? [];
      final List<Client> fetchedClients = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      // Build a map for efficient client lookup
      final Map<int, Client> clientMap = {
        for (var c in fetchedClients) c.id: c
      };

      // Create new JourneyPlan objects with full client data
      final List<JourneyPlan> updatedJourneyPlans = fetchedPlans.map((plan) {
        final Client client = clientMap[plan.client.id] ?? plan.client;
        return JourneyPlan(
          id: plan.id,
          date: plan.date,
          time: plan.time,
          salesRepId: plan.salesRepId,
          status: plan.status,
          routeId: plan.routeId,
          client: client,
          showUpdateLocation: plan.showUpdateLocation,
        );
      }).toList();

      // Update state
      if (page == 1) {
        journeyPlans.value = updatedJourneyPlans;
        clients.value = fetchedClients;
        currentPage.value = 1;
        hasMoreData.value = journeyPlansResult.totalPages > 1;
      } else {
        journeyPlans.addAll(updatedJourneyPlans);
        currentPage.value = page;
        hasMoreData.value = page < journeyPlansResult.totalPages;
      }

      lastRefresh.value = DateTime.now();

      print('✅ Loaded ${updatedJourneyPlans.length} journey plans');
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to load journey plans: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh data (debounced)
  Future<void> _refreshData() async {
    if (isRefreshing.value) return;

    try {
      isRefreshing.value = true;
      await loadJourneyPlans(forceRefresh: true);
    } catch (e) {
      print('❌ Failed to refresh journey plans: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Load more data for pagination
  Future<void> loadMoreData() async {
    if (isLoadingMore.value || !hasMoreData.value) return;

    try {
      isLoadingMore.value = true;
      await loadJourneyPlans(
        page: currentPage.value + 1,
        status: selectedStatus.value,
        date: selectedDate.value,
      );
    } catch (e) {
      print('❌ Failed to load more journey plans: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Refresh specific journey plan status
  Future<void> refreshJourneyPlanStatus(int journeyPlanId) async {
    try {
      // Add rate limiting - don't refresh if we just refreshed this plan
      final lastRefreshTime = _lastRefreshTimes[journeyPlanId];
      if (lastRefreshTime != null) {
        final timeSinceLastRefresh = DateTime.now().difference(lastRefreshTime);
        if (timeSinceLastRefresh < const Duration(minutes: 2)) {
          print(
              '⏳ Skipping refresh for journey plan $journeyPlanId - too recent');
          return;
        }
      }

      final updatedPlan =
          await JourneyPlanService.getJourneyPlanById(journeyPlanId);

      if (updatedPlan != null) {
        final index = journeyPlans.indexWhere((p) => p.id == journeyPlanId);
        if (index != -1) {
          journeyPlans[index] = updatedPlan;
        }

        // Update selected journey plan if it's the same
        if (selectedJourneyPlan.value?.id == journeyPlanId) {
          selectedJourneyPlan.value = updatedPlan;
        }

        // Update last refresh time
        _lastRefreshTimes[journeyPlanId] = DateTime.now();
      }
    } catch (e) {
      print('❌ Failed to refresh journey plan status: $e');
      // Don't retry on errors to prevent excessive API calls
    }
  }

  /// Get journey plan by ID
  JourneyPlan? getJourneyPlanById(int id) {
    try {
      return journeyPlans.firstWhere((plan) => plan.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Filter journey plans
  List<JourneyPlan> getFilteredJourneyPlans({
    String? status,
    DateTime? date,
    String? searchQuery,
  }) {
    var filtered = journeyPlans.where((plan) {
      // Status filter
      if (status != null && plan.statusText != status) {
        return false;
      }

      // Date filter
      if (date != null) {
        final planDate =
            DateTime(plan.date.year, plan.date.month, plan.date.day);
        final filterDate = DateTime(date.year, date.month, date.day);
        if (planDate != filterDate) {
          return false;
        }
      }

      // Search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final clientName = plan.client.name.toLowerCase() ?? '';
        final clientAddress = (plan.client.address ?? '').toLowerCase();

        if (!clientName.contains(query) && !clientAddress.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  /// Set filters
  void setFilters({
    String? status,
    DateTime? date,
  }) {
    selectedStatus.value = status;
    selectedDate.value = date;
  }

  /// Clear filters
  void clearFilters() {
    selectedStatus.value = null;
    selectedDate.value = null;
  }

  /// Select journey plan
  void selectJourneyPlan(JourneyPlan journeyPlan) {
    selectedJourneyPlan.value = journeyPlan;
  }

  /// Clear selected journey plan
  void clearSelectedJourneyPlan() {
    selectedJourneyPlan.value = null;
  }

  /// Parse status string to enum
  JourneyPlanStatus? _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return JourneyPlanStatus.pending;
      case 'checked_in':
        return JourneyPlanStatus.checked_in;
      case 'in_progress':
        return JourneyPlanStatus.in_progress;
      case 'completed':
        return JourneyPlanStatus.completed;
      case 'cancelled':
        return JourneyPlanStatus.cancelled;
      default:
        return null;
    }
  }

  /// Get current user route ID
  Future<int?> _getCurrentUserRouteId() async {
    try {
      // This should be implemented based on your user service
      // For now, returning null to fetch all clients
      return null;
    } catch (e) {
      print('❌ Failed to get current user route ID: $e');
      return null;
    }
  }

  /// Force refresh data
  Future<void> forceRefresh() async {
    await loadJourneyPlans(forceRefresh: true);
  }

  /// Get loading state
  bool get isDataLoading => isLoading.value || isRefreshing.value;

  /// Get error message
  String? get errorMessage => error.value;

  /// Check if there's an error
  bool get hasError => error.value != null;

  /// Clear error
  void clearError() {
    error.value = null;
  }
}
