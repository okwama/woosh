import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/pages/journeyplan/createJourneyplan.dart';
import 'package:woosh/pages/journeyplan/journeyview.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/hive/journey_plan_hive_service.dart';
import '../../models/hive/journey_plan_model.dart';

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
      // Initialize Hive service
      final hiveService = JourneyPlanHiveService();
      await hiveService.init();

      // Load cached data first
      final cachedPlans = hiveService.getAllJourneyPlans();

      // PRIORITY: Load journey plans first (primary data)
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);

      // Save journey plans to Hive immediately
      if (journeyPlans.isNotEmpty) {
        final journeyPlanModels = journeyPlans
            .map((plan) => JourneyPlanModel(
                  id: plan.id ?? 0,
                  date: plan.date,
                  time: plan.time,
                  userId: plan.salesRepId ?? 0,
                  clientId: plan.client.id,
                  status: plan.status,
                  showUpdateLocation: plan.showUpdateLocation,
                  routeId: plan.routeId,
                ))
            .toList();
        await hiveService.saveJourneyPlans(journeyPlanModels);
      }

      // Load clients in background (secondary data)
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse = await ApiService.fetchClients(routeId: routeId);

      // Navigate to main page with preloaded data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JourneyPlansPage(
              preloadedClients: clientsResponse.data,
              preloadedPlans: journeyPlans,
              cachedPlans: cachedPlans,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error preloading data: $e');
      // If there's an error, still navigate but with cached data
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
  final List<JourneyPlanModel>? cachedPlans;

  const JourneyPlansPage({
    super.key,
    this.preloadedClients,
    this.preloadedPlans,
    this.cachedPlans,
  });

  @override
  State<JourneyPlansPage> createState() => _JourneyPlansPageState();
}

class _JourneyPlansPageState extends State<JourneyPlansPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingClients = false;
  List<Client> _clients = [];
  List<JourneyPlan> _journeyPlans = [];
  final Set<int> _hiddenJourneyPlans = {};
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  JourneyPlan? _activeVisit;

  final JourneyPlanHiveService _hiveService = JourneyPlanHiveService();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isCustomRange = false;
  bool _showFuturePlans = true;

  @override
  void initState() {
    super.initState();
    _initHiveService();

    // Use preloaded data if available
    if (widget.preloadedClients != null) {
      _clients = widget.preloadedClients!;
    }
    if (widget.preloadedPlans != null) {
      _journeyPlans = widget.preloadedPlans!;
      _isLoading = false;
    } else if (widget.cachedPlans != null && widget.cachedPlans!.isNotEmpty) {
      _journeyPlans = widget.cachedPlans!.map(_convertToJourneyPlan).toList();
      _isLoading = false;
    } else {
      _loadData();
    }

    _scrollController.addListener(_onScroll);
    _checkActiveVisit();
  }

  Future<void> _initHiveService() async {
    try {
      await _hiveService.init();
      _loadCachedJourneyPlans();
    } catch (e) {
      debugPrint('Error initializing Hive service: $e');
    }
  }

  void _loadCachedJourneyPlans() {
    try {
      final cachedPlans = _hiveService.getAllJourneyPlans();
      if (cachedPlans.isNotEmpty) {
        final journeyPlans = cachedPlans.map(_convertToJourneyPlan).toList();
        setState(() {
          _journeyPlans = journeyPlans;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached journey plans: $e');
    }
  }

  JourneyPlan _convertToJourneyPlan(JourneyPlanModel model) {
    return JourneyPlan(
      id: model.id,
      date: model.date,
      time: model.time,
      salesRepId: model.userId,
      status: model.status,
      routeId: model.routeId,
      client: _findClientById(model.clientId),
      showUpdateLocation: model.showUpdateLocation,
    );
  }

  Client _findClientById(int clientId) {
    try {
      return _clients.firstWhere((client) => client.id == clientId);
    } catch (e) {
      return Client(
        id: clientId,
        name: '',
        address: '',
        regionId: 0,
        region: '',
        countryId: 0,
      );
    }
  }

  Future<void> _loadClients() async {
    if (_isLoadingClients) return;

    setState(() {
      _isLoadingClients = true;
    });

    try {
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse = await ApiService.fetchClients(routeId: routeId);
      setState(() {
        _clients = clientsResponse.data;
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
    } finally {
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      final newPlans = await ApiService.fetchJourneyPlans(
        page: _currentPage + 1,
      );

      if (newPlans.isEmpty) {
        setState(() {
          _hasMoreData = false;
        });
      } else {
        setState(() {
          _journeyPlans.addAll(newPlans);
          _currentPage++;
        });
        _saveJourneyPlansToHive(newPlans);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more data: ${e.toString()}')),
      );
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
        _currentPage = 1;
        _hasMoreData = true;
      });
    }

    try {
      // PRIORITY: Load journey plans first (primary data)
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);

      if (mounted) {
        setState(() {
          _journeyPlans = journeyPlans;
          _isLoading = false;
        });
        _saveJourneyPlansToHive(journeyPlans);
      }

      // Load clients in background (secondary data)
      _loadClients();
    } catch (e) {
      print('Error loading data: $e');

      if (_journeyPlans.isEmpty) {
        _loadCachedJourneyPlans();
      }

      setState(() {
        _isLoading = false;
      });

      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('timeout')) {
        _showGenericErrorDialog();
      } else {
        _showGenericErrorDialog();
      }
    }
  }

  List<JourneyPlan> _getFilteredPlans() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _journeyPlans.where((plan) {
      if (_hiddenJourneyPlans.contains(plan.id)) return false;

      final localPlanDate = plan.date.toLocal();
      final planDateOnly =
          DateTime(localPlanDate.year, localPlanDate.month, localPlanDate.day);

      if (_isCustomRange) {
        final startDateOnly =
            DateTime(_startDate.year, _startDate.month, _startDate.day);
        final endDateOnly =
            DateTime(_endDate.year, _endDate.month, _endDate.day);

        return planDateOnly.isAtSameMomentAs(startDateOnly) ||
            planDateOnly.isAtSameMomentAs(endDateOnly) ||
            (planDateOnly.isAfter(startDateOnly) &&
                planDateOnly.isBefore(endDateOnly));
      } else {
        return _showFuturePlans
            ? planDateOnly.isAtSameMomentAs(today) ||
                planDateOnly.isAfter(today)
            : planDateOnly.isAtSameMomentAs(today);
      }
    }).toList();
  }

  void _showGenericErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Something went wrong. Please try again.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkActiveVisit() async {
    try {
      final activeVisit = await ApiService.getActiveVisit();
      setState(() {
        _activeVisit = activeVisit;
      });
    } catch (e) {
      print('Error checking active visit: $e');
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
        final routeId = ApiService.getCurrentUserRouteId();
        final clientsResponse = await ApiService.fetchClients(routeId: routeId);
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
                  _saveJourneyPlansToHive(newJourneyPlans);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Journey plan created successfully')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load clients: ${e.toString()}')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isToday
              ? 'You can only navigate to today\'s journey plans'
              : hasInProgressToday
                  ? 'Please complete the active journey plan first'
                  : 'You can only navigate to today\'s active journey plans'),
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
                              final index = _journeyPlans
                                  .indexWhere((p) => p.id == updatedPlan.id);
                              if (index != -1) {
                                _journeyPlans[index] = updatedPlan;
                              }
                              _activeVisit = updatedPlan;
                            });
                          },
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
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
          },
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomRange = true;
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

  Future<void> _saveJourneyPlansToHive(List<JourneyPlan> journeyPlans) async {
    try {
      final journeyPlanModels =
          journeyPlans.map(_convertToJourneyPlanModel).toList();
      await _hiveService.saveJourneyPlans(journeyPlanModels);
    } catch (e) {
      debugPrint('Error saving journey plans to Hive: $e');
    }
  }

  JourneyPlanModel _convertToJourneyPlanModel(JourneyPlan plan) {
    return JourneyPlanModel(
      id: plan.id ?? 0,
      date: plan.date,
      time: plan.time,
      userId: plan.salesRepId ?? 0,
      clientId: plan.client.id,
      status: plan.status,
      showUpdateLocation: plan.showUpdateLocation,
      routeId: plan.routeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Journey Plans',
        actions: [
          IconButton(
            icon: Icon(_showFuturePlans
                ? Icons.calendar_today
                : Icons.calendar_view_day),
            tooltip: _showFuturePlans ? 'Show Only Today' : 'Show Future Plans',
            onPressed: () {
              setState(() {
                _showFuturePlans = !_showFuturePlans;
                _isCustomRange = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
            onPressed: () => _showDateRangePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading && _journeyPlans.isEmpty
          ? const JourneyPlansSkeleton()
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isCustomRange
                                ? '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}'
                                : _showFuturePlans
                                    ? 'Upcoming Plans'
                                    : 'Today\'s Plans',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isCustomRange)
                            TextButton.icon(
                              icon: const Icon(Icons.today),
                              label: const Text('Show Upcoming'),
                              onPressed: () {
                                setState(() {
                                  _isCustomRange = false;
                                  _showFuturePlans = true;
                                });
                              },
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${_getFilteredPlans().length} plans found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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
                                isLoadingClient: _isLoadingClients,
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
  final bool isLoadingClient;
  final bool hasActiveVisit;
  final JourneyPlan? activeVisit;

  const JourneyPlanItem({
    super.key,
    required this.journeyPlan,
    required this.onTap,
    this.onHide,
    this.isLoadingClient = false,
    required this.hasActiveVisit,
    this.activeVisit,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = journeyPlan.statusText == 'Completed';
    final isInProgress = journeyPlan.statusText == 'In progress';
    final isCheckedIn = journeyPlan.statusText == 'Checked In';
    final isPending = journeyPlan.statusText == 'Pending';
    final clientName = journeyPlan.client.name;
    final isClientLoading = clientName.isEmpty || isLoadingClient;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDate = journeyPlan.date.toLocal();
    final isToday =
        DateTime(planDate.year, planDate.month, planDate.day) == today;

    // Only disable if completed or client is loading
    final shouldDisable = isCompleted || isClientLoading;

    return Opacity(
      opacity: isCompleted ? 0.5 : 1.0,
      child: Card(
        key: ValueKey('journey_plan_${journeyPlan.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: InkWell(
          onTap: shouldDisable ? null : onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                const Icon(Icons.store, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isClientLoading)
                        _buildClientNameShimmer()
                      else
                        Text(
                          clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy')
                            .format(journeyPlan.date.toLocal()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isClientLoading) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: journeyPlan.statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      journeyPlan.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientNameShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 120,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class JourneyPlansSkeleton extends StatelessWidget {
  const JourneyPlansSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const SkeletonLoader(
            height: 80,
            width: double.infinity,
            radius: 10,
          ),
        );
      },
    );
  }
}
