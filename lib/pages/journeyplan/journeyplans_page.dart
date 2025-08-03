import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/pages/journeyplan/create_journey_plan.dart';
import 'package:woosh/pages/journeyplan/journeyview.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/services/journeyplan/journey_plan_state_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:woosh/services/client/client_service.dart';

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
      final journeyPlansResponse =
          await JourneyPlanService.fetchJourneyPlans(page: 1);
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse =
          await ClientService.fetchClients(routeId: routeId);

      // Convert the response to the expected format
      final List<dynamic> clientData = clientsResponse['data'] ?? [];
      final List<Client> clients = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      // Navigate to main page with preloaded data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JourneyPlansPage(
              preloadedClients: clients,
              preloadedPlans: journeyPlansResponse.data,
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
  late final JourneyPlanStateService _journeyPlanStateService;
  final Set<int> _hiddenJourneyPlans = {};
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  JourneyPlan? _activeVisit;
  bool _isShowingNotification = false;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Get the journey plan state service
    _journeyPlanStateService = Get.find<JourneyPlanStateService>();

    // Use preloaded data if available
    if (widget.preloadedClients != null) {
      _journeyPlanStateService.clients.assignAll(widget.preloadedClients!);
    }
    if (widget.preloadedPlans != null) {
      _journeyPlanStateService.journeyPlans.assignAll(widget.preloadedPlans!);
    } else {
      _loadData();
    }

    _scrollController.addListener(_onScroll);
    _checkActiveVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer need to refresh on every dependency change
    // The state service handles this automatically
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Use the state service's debounced refresh
      _journeyPlanStateService.forceRefresh();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_journeyPlanStateService.isLoading.value &&
          _journeyPlanStateService.hasMoreData.value) {
        _journeyPlanStateService.loadMoreData();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      await _journeyPlanStateService.loadJourneyPlans();
    } catch (e) {
      if (mounted) {
        _showGenericErrorDialog();
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      await _journeyPlanStateService.forceRefresh();
    } catch (e) {
      print('Failed to refresh journey plans: $e');
    }
  }

  List<JourneyPlan> _getFilteredPlans() {
    // Remove date filtering - show all plans
    var filteredPlans = _journeyPlanStateService.journeyPlans.where((plan) {
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
      if (_journeyPlanStateService.clients.isEmpty) {
        final clientsResponse = await ClientService.fetchClients(
            routeId: null); // Don't filter by route
        final List<dynamic> clientData = clientsResponse['data'] ?? [];
        final List<Client> clients = clientData
            .map((json) => Client.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _journeyPlanStateService.clients.assignAll(clients);
        });
      }

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateJourneyPlanPage(
              clients: _journeyPlanStateService.clients,
              onSuccess: (newJourneyPlans) {
                if (newJourneyPlans.isNotEmpty) {
                  setState(() {
                    _journeyPlanStateService.journeyPlans
                        .insert(0, newJourneyPlans[0]);
                  });
                }
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
    final hasInProgressToday =
        _journeyPlanStateService.journeyPlans.any((plan) {
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

      // Only show notification if one isn't already showing and it's a critical navigation restriction
      if (!_isShowingNotification && (!isToday || hasInProgressToday)) {
        _isShowingNotification = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content:
                    const Text('Please complete the active journey plan first'),
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
                                    final index = _journeyPlanStateService
                                        .journeyPlans
                                        .indexWhere(
                                            (p) => p.id == updatedPlan.id);
                                    if (index != -1) {
                                      _journeyPlanStateService
                                          .journeyPlans[index] = updatedPlan;
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
              final index = _journeyPlanStateService.journeyPlans
                  .indexWhere((p) => p.id == updatedPlan.id);
              if (index != -1) {
                _journeyPlanStateService.journeyPlans[index] = updatedPlan;
              }
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
      // Use the centralized state service instead of direct API calls
      await _journeyPlanStateService.refreshJourneyPlanStatus(journeyPlanId);

      // Update active visit if this was the active one
      final updatedPlan = _journeyPlanStateService.journeyPlans.firstWhere(
          (p) => p.id == journeyPlanId,
          orElse: () => _activeVisit!);

      if (mounted && _activeVisit?.id == journeyPlanId) {
        setState(() {
          _activeVisit = updatedPlan;
        });
      }
    } catch (e) {
      print('Failed to refresh journey plan status: $e');
      // Don't retry automatically - let the state service handle retries
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
      // Call API to delete journey plan
      await JourneyPlanService.deleteJourneyPlan(journeyPlan.id!);

      // Remove from local list
      setState(() {
        _journeyPlanStateService.journeyPlans
            .removeWhere((plan) => plan.id == journeyPlan.id);
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Journey plan deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Failed to delete journey plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete journey plan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Immediate UI update method for instant feedback
  void _updateJourneyPlanStatus(int journeyId, int newStatus) {
    setState(() {
      final index = _journeyPlanStateService.journeyPlans
          .indexWhere((plan) => plan.id == journeyId);
      if (index != -1) {
        _journeyPlanStateService.journeyPlans[index] = _journeyPlanStateService
            .journeyPlans[index]
            .copyWith(status: newStatus);
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
      body: _journeyPlanStateService.isLoading.value &&
              _journeyPlanStateService.journeyPlans.isEmpty
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
                                (_journeyPlanStateService.hasMoreData.value
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (index == _getFilteredPlans().length) {
                                return _journeyPlanStateService
                                        .isLoadingMore.value
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
