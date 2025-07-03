import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
<<<<<<< HEAD
import 'package:woosh/models/client_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/pages/journeyplan/createJourneyplan.dart';
import 'package:woosh/pages/journeyplan/journeyview.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/jouneyplan_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
=======
import 'package:glamour_queen/models/client_model.dart';
import 'package:glamour_queen/models/journeyplan_model.dart';
import 'package:glamour_queen/pages/journeyplan/createJourneyplan.dart';
import 'package:glamour_queen/pages/journeyplan/journeyview.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

class JourneyPlansLoadingScreen extends StatefulWidget {
  const JourneyPlansLoadingScreen({super.key});

  @override
  State<JourneyPlansLoadingScreen> createState() =>
      _JourneyPlansLoadingScreenState();
}

class _JourneyPlansLoadingScreenState extends State<JourneyPlansLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _preloadData();
  }

  Future<void> _preloadData() async {
    try {
      // Load journey plans and clients from the server
<<<<<<< HEAD
      final journeyPlansResponse =
          await JourneyPlanService.fetchJourneyPlans(page: 1);
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse = await ApiService.fetchClients(routeId: routeId);
=======
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);
      final clientsResponse =
          await ApiService.fetchClients(routeId: null); // Don't filter by route
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

      // Navigate to main page with preloaded data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JourneyPlansPage(
              preloadedClients: clientsResponse.data,
<<<<<<< HEAD
              preloadedPlans: journeyPlansResponse.data,
=======
              preloadedPlans: journeyPlans,
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
            ),
          ),
        );
      }
    } catch (e) {
      print('Error preloading data: $e');
      // If there's an error, still navigate but with empty data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const JourneyPlansPage(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading Journey Plans...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyPlansPage extends StatefulWidget {
  final List<Client>? preloadedClients;
  final List<JourneyPlan>? preloadedPlans;

  const JourneyPlansPage({
    super.key,
    this.preloadedClients,
    this.preloadedPlans,
  });

  @override
  State<JourneyPlansPage> createState() => _JourneyPlansPageState();
}

class _JourneyPlansPageState extends State<JourneyPlansPage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Client> _clients = [];
  List<JourneyPlan> _journeyPlans = [];
  final Set<int> _hiddenJourneyPlans = {};
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  JourneyPlan? _activeVisit;
  bool _isShowingNotification = false;
  Timer? _refreshTimer;

  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Use preloaded data if available
    if (widget.preloadedClients != null) {
      _clients = widget.preloadedClients!;
    }
    if (widget.preloadedPlans != null) {
      _journeyPlans = widget.preloadedPlans!;
      _isLoading = false;
    } else {
      _loadData();
    }

    _scrollController.addListener(_onScroll);
    _checkActiveVisit();

    // Start periodic refresh every 60 seconds
    _startPeriodicRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when page becomes visible (e.g., returning from other screens)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      _refreshData();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    try {
      // Quick refresh without showing loading state
<<<<<<< HEAD
      final routeId = ApiService.getCurrentUserRouteId();
      final journeyPlansFuture = JourneyPlanService.fetchJourneyPlans(page: 1);
      final clientsFuture = ApiService.fetchClients(routeId: routeId);
=======
      final journeyPlansFuture = ApiService.fetchJourneyPlans(page: 1);
      final clientsFuture =
          ApiService.fetchClients(routeId: null); // Don't filter by route
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

      final journeyPlansResult = await journeyPlansFuture;
      final clientsResult = await clientsFuture;

<<<<<<< HEAD
      final List<JourneyPlan> fetchedPlans = journeyPlansResult.data;
=======
      final List<JourneyPlan> fetchedPlans = journeyPlansResult;
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      final List<Client> clients = clientsResult.data;

      // Build a map for efficient client lookup
      final Map<int, Client> clientMap = {for (var c in clients) c.id: c};

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

      if (mounted) {
        setState(() {
          _journeyPlans = updatedJourneyPlans;
          _clients = clients;
        });
      }
    } catch (e) {
      // Silent fail for background refresh
<<<<<<< HEAD
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('Server error during refresh - handled silently: $e');
      } else {
        print('Failed to refresh journey plans: $e');
      }
=======
      print('Background refresh failed: $e');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPlans = await JourneyPlanService.fetchJourneyPlans(
        page: _currentPage + 1,
      );

      if (newPlans.data.isEmpty) {
        setState(() {
          _hasMoreData = false;
        });
      } else {
        setState(() {
          _journeyPlans.addAll(newPlans.data);
          _currentPage++;
        });
      }
    } catch (e) {
      // Silent fail for server errors
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('Server error during load more - handled silently: $e');
      } else {
        print('Failed to load more journey plans: $e');
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Fetch journey plans and clients in parallel
<<<<<<< HEAD
      final routeId = ApiService.getCurrentUserRouteId();
      final journeyPlansFuture = JourneyPlanService.fetchJourneyPlans(page: 1);
      final clientsFuture = ApiService.fetchClients(routeId: routeId);
=======
      final journeyPlansFuture = ApiService.fetchJourneyPlans(page: 1);
      final clientsFuture =
          ApiService.fetchClients(routeId: null); // Don't filter by route
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

      // Await both futures
      final journeyPlansResult = await journeyPlansFuture;
      final clientsResult = await clientsFuture;

<<<<<<< HEAD
      final List<JourneyPlan> fetchedPlans = journeyPlansResult.data;
=======
      final List<JourneyPlan> fetchedPlans = journeyPlansResult;
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      final List<Client> clients = clientsResult.data;

      // Build a map for efficient client lookup
      final Map<int, Client> clientMap = {for (var c in clients) c.id: c};

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

      if (mounted) {
        setState(() {
          _journeyPlans = updatedJourneyPlans;
<<<<<<< HEAD
          _clients = clients;
=======
          _clients = clients; // Store clients for other uses
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
          _currentPage = 1;
          _hasMoreData = true;
        });
      }
    } catch (e) {
<<<<<<< HEAD
      // Silent fail for server errors
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('Server error during load - handled silently: $e');
      } else {
        print('Failed to load journey plans: $e');
=======
      print('Error loading data: $e');
      if (mounted) {
        _showGenericErrorDialog();
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<JourneyPlan> _getFilteredPlans() {
    // Remove date filtering - show all plans
    var filteredPlans = _journeyPlans.where((plan) {
      return !_hiddenJourneyPlans.contains(plan.id);
    }).toList();

    // Sort by creation date (newest first when ascending, oldest first when descending)
    filteredPlans.sort((a, b) {
      if (_sortAscending) {
        // Newest first (descending by date)
        return b.date.compareTo(a.date);
      } else {
        // Oldest first (ascending by date)
        return a.date.compareTo(b.date);
      }
    });

    return filteredPlans;
  }

  void _showGenericErrorDialog() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Could not refresh plans. Please check your connection.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadData,
        ),
      ),
    );
  }

  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('connection timeout') ||
        errorString.contains('network error') ||
        errorString.contains('connection refused') ||
        errorString.contains('no internet') ||
        errorString.contains('xmlhttprequest error') ||
        errorString.contains('failed to connect') ||
        errorString.contains('timeout');
  }

  Future<void> _checkActiveVisit() async {
    try {
      final activeVisit = await JourneyPlanService.getActiveVisit();
      setState(() {
        _activeVisit = activeVisit;
      });
    } catch (e) {
      print('Failed to check active visit');
    }
  }

  Future<void> _navigateToCreateJourneyPlan() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_clients.isEmpty) {
        final clientsResponse = await ApiService.fetchClients(
            routeId: null); // Don't filter by route
        setState(() {
          _clients = clientsResponse.data;
        });
      }

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateJourneyPlanPage(
              clients: _clients,
              onSuccess: (newJourneyPlans) {
                if (newJourneyPlans.isNotEmpty) {
                  setState(() {
                    _journeyPlans.insert(0, newJourneyPlans[0]);
                  });
                }
<<<<<<< HEAD
=======
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Journey plan created successfully')),
                );
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        // Silent fail for all errors
        print('Failed to load clients');
      }
    }
  }

  void _navigateToJourneyView(JourneyPlan journeyPlan) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDate = journeyPlan.date.toLocal();
    final isToday =
        DateTime(planDate.year, planDate.month, planDate.day) == today;
    final isInProgress = journeyPlan.statusText == 'In progress';
    final isCheckedIn = journeyPlan.statusText == 'Checked In';
    final isPending = journeyPlan.statusText == 'Pending';

    // Check if there are any in-progress journey plans for today
    final hasInProgressToday = _journeyPlans.any((plan) {
      final planDate = plan.date.toLocal();
      final planDateOnly =
          DateTime(planDate.year, planDate.month, planDate.day);
      return planDateOnly == today &&
          (plan.statusText == 'In progress' || plan.statusText == 'Checked In');
    });

    // Allow navigation if journey is in progress/checked in OR if it's pending with no in-progress JPs
    final canNavigate =
        isInProgress || isCheckedIn || (isPending && !hasInProgressToday);

    if (!isToday || !canNavigate) {
      HapticFeedback.vibrate();

<<<<<<< HEAD
      // Only show notification if one isn't already showing and it's a critical navigation restriction
      if (!_isShowingNotification && (!isToday || hasInProgressToday)) {
=======
      // Only show notification if one isn't already showing
      if (!_isShowingNotification) {
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
        _isShowingNotification = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(!isToday
                    ? 'You can only navigate to today\'s journey plans'
<<<<<<< HEAD
                    : 'Please complete the active journey plan first'),
=======
                    : hasInProgressToday
                        ? 'Please complete the active journey plan first'
                        : 'You can only navigate to today\'s active journey plans'),
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
                action: _activeVisit != null &&
                        _activeVisit!.id != journeyPlan.id &&
                        !isInProgress &&
                        !isCheckedIn
                    ? SnackBarAction(
                        label: 'Go to Active',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JourneyView(
                                journeyPlan: _activeVisit!,
                                onCheckInSuccess: (updatedPlan) {
                                  setState(() {
                                    final index = _journeyPlans.indexWhere(
                                        (p) => p.id == updatedPlan.id);
                                    if (index != -1) {
                                      _journeyPlans[index] = updatedPlan;
                                    }
                                    _activeVisit = updatedPlan;
                                  });
                                  // Immediate UI update
                                  _updateJourneyPlanStatus(
                                      updatedPlan.id!, updatedPlan.status);
                                },
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            )
            .closed
            .then((_) {
          _isShowingNotification = false;
        });
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyView(
          journeyPlan: journeyPlan,
          onCheckInSuccess: (updatedPlan) {
            setState(() {
              final index =
                  _journeyPlans.indexWhere((p) => p.id == updatedPlan.id);
              if (index != -1) _journeyPlans[index] = updatedPlan;
              _activeVisit = updatedPlan;
            });
            // Immediate UI update
            _updateJourneyPlanStatus(updatedPlan.id!, updatedPlan.status);
          },
        ),
      ),
    ).then((_) {
      // Immediate status refresh when returning
      if (mounted) {
        _refreshJourneyPlanStatus(journeyPlan.id!);
        // Also refresh after a short delay as backup
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _refreshJourneyPlanStatus(journeyPlan.id!);
          }
        });
      }
    });
  }

  // Add method to refresh specific journey plan status
  Future<void> _refreshJourneyPlanStatus(int journeyPlanId) async {
    try {
<<<<<<< HEAD
      // Fetch the updated journey plan from the server
      final updatedPlan =
          await JourneyPlanService.getJourneyPlanById(journeyPlanId);

=======
      print('Refreshing journey plan status for ID: $journeyPlanId');

      // Fetch the updated journey plan from the server
      final updatedPlan = await ApiService.getJourneyPlanById(journeyPlanId);

>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      if (updatedPlan != null && mounted) {
        setState(() {
          final index = _journeyPlans.indexWhere((p) => p.id == journeyPlanId);
          if (index != -1) {
            _journeyPlans[index] = updatedPlan;
<<<<<<< HEAD
=======
            print('Updated journey plan status to: ${updatedPlan.statusText}');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
          }

          // Update active visit if this was the active one
          if (_activeVisit?.id == journeyPlanId) {
            _activeVisit = updatedPlan;
<<<<<<< HEAD
=======
            print('Updated active visit status to: ${updatedPlan.statusText}');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
          }
        });

        // If still not completed, try one more time after a short delay
        if (updatedPlan.statusText != 'Completed') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _refreshJourneyPlanStatus(journeyPlanId);
            }
          });
        }
      }
    } catch (e) {
<<<<<<< HEAD
      print('Failed to refresh journey plan status');
=======
      print('Error refreshing journey plan status: $e');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      // Try again after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _refreshJourneyPlanStatus(journeyPlanId);
        }
      });
    }
  }

  void _hideJourneyPlan(int journeyPlanId) {
    setState(() {
      _hiddenJourneyPlans.add(journeyPlanId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Journey plan hidden'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _hiddenJourneyPlans.remove(journeyPlanId);
            });
          },
        ),
      ),
    );
  }

  Future<void> _deleteJourneyPlan(JourneyPlan journeyPlan) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Journey Plan'),
        content: Text(
          'Are you sure you want to delete the journey plan for ${journeyPlan.client.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
<<<<<<< HEAD
      // Call API to delete journey plan
      await JourneyPlanService.deleteJourneyPlan(journeyPlan.id!);
=======
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting journey plan...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Call API to delete journey plan
      await ApiService.deleteJourneyPlan(journeyPlan.id!);
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

      // Remove from local list
      setState(() {
        _journeyPlans.removeWhere((plan) => plan.id == journeyPlan.id);
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
<<<<<<< HEAD
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Journey plan deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
=======
            content: Text('Journey plan deleted successfully'),
            backgroundColor: Colors.green,
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
          ),
        );
      }
    } catch (e) {
<<<<<<< HEAD
      // Silent fail for all errors
      print('Failed to delete journey plan');
=======
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete journey plan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    }
  }

  // Immediate UI update method for instant feedback
  void _updateJourneyPlanStatus(int journeyId, int newStatus) {
    setState(() {
      final index = _journeyPlans.indexWhere((plan) => plan.id == journeyId);
      if (index != -1) {
        _journeyPlans[index] = _journeyPlans[index].copyWith(status: newStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Journey Plans',
        actions: [
          IconButton(
            icon: Icon(_sortAscending ? Icons.sort : Icons.sort_by_alpha),
            tooltip: _sortAscending ? 'Sort Descending' : 'Sort Ascending',
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading && _journeyPlans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: const Center(
                    child: Text(
                      'My Journey Plans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _getFilteredPlans().isEmpty
                        ? const Center(child: Text('No journey plans found'))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _getFilteredPlans().length +
                                (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _getFilteredPlans().length) {
                                return _isLoadingMore
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }

                              final journeyPlan = _getFilteredPlans()[index];
                              return JourneyPlanItem(
                                journeyPlan: journeyPlan,
                                onTap: () =>
                                    _navigateToJourneyView(journeyPlan),
                                onHide: journeyPlan.statusText == 'Completed' &&
                                        journeyPlan.id != null
                                    ? () => _hideJourneyPlan(journeyPlan.id!)
                                    : null,
                                onDelete: journeyPlan.statusText == 'Pending' &&
                                        journeyPlan.id != null
                                    ? () => _deleteJourneyPlan(journeyPlan)
                                    : null,
                                hasActiveVisit: _activeVisit != null &&
                                    _activeVisit!.id != journeyPlan.id,
                                activeVisit: _activeVisit,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateJourneyPlan,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class JourneyPlanItem extends StatelessWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback onTap;
  final VoidCallback? onHide;
  final VoidCallback? onDelete;
  final bool hasActiveVisit;
  final JourneyPlan? activeVisit;

  const JourneyPlanItem({
    super.key,
    required this.journeyPlan,
    required this.onTap,
    this.onHide,
    this.onDelete,
    required this.hasActiveVisit,
    this.activeVisit,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = journeyPlan.statusText == 'Completed';
    final isPending = journeyPlan.statusText == 'Pending';
    final clientName = journeyPlan.client.name;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDate = journeyPlan.date.toLocal();
    final isToday =
        DateTime(planDate.year, planDate.month, planDate.day) == today;

    // Only disable if completed
    final shouldDisable = isCompleted;

    return Opacity(
      opacity: isCompleted ? 0.5 : 1.0,
      child: Card(
        key: ValueKey('journey_plan_${journeyPlan.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: InkWell(
          onTap: shouldDisable ? null : onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                // Left section: Action icons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending && onDelete != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          onPressed: onDelete,
                          tooltip: 'Delete journey plan',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.store,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Center section: Client info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy')
                            .format(journeyPlan.date.toLocal()),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right section: Status and arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: journeyPlan.statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        journeyPlan.statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
