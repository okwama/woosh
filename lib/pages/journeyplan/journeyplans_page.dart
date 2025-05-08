import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/pages/journeyplan/journeyview.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';

class JourneyPlansPage extends StatefulWidget {
  const JourneyPlansPage({super.key});

  @override
  State<JourneyPlansPage> createState() => _JourneyPlansPageState();
}

class _JourneyPlansPageState extends State<JourneyPlansPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Client> _clients = [];
  List<JourneyPlan> _journeyPlans = [];
  Set<int> _hiddenJourneyPlans = {};
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  static const String _journeyPlansCacheKey = 'cached_journey_plans';
  static const String _clientsCacheKey = 'cached_clients';
  static const int _prefetchThreshold =
      5; // Start loading when 5 items from bottom
  static const int _pageSize = 10; // Items per page
  JourneyPlan? _activeVisit; // Add this to track active visit

  // Add date filtering state
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isCustomRange = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadData();
    _scrollController.addListener(_onScroll);
    _checkActiveVisit(); // Add this to check for active visits on init
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 200px threshold
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
      // Prefetch next page
      final newPlans = await ApiService.fetchJourneyPlans(
        page: _currentPage + 1,
        limit: _pageSize,
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
        _cacheData(); // Cache the new data
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

  Future<void> _loadCachedData() async {
    try {
      final cachedPlans =
          ApiService.getCachedData<List<JourneyPlan>>(_journeyPlansCacheKey);
      final cachedClients =
          ApiService.getCachedData<List<Client>>(_clientsCacheKey);

      if (cachedPlans != null && cachedClients != null) {
        setState(() {
          _journeyPlans = cachedPlans;
          _clients = cachedClients;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _cacheData() async {
    try {
      ApiService.cacheData(_journeyPlansCacheKey, _journeyPlans);
      ApiService.cacheData(_clientsCacheKey, _clients);
    } catch (e) {
      print('Error caching data: $e');
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
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse = await ApiService.fetchClients(routeId: routeId);
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);

      if (mounted) {
        setState(() {
          _clients = clientsResponse.data;
          _journeyPlans = journeyPlans;
          _isLoading = false;
        });
        _cacheData(); // Cache the new data
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Check if it's a connection error
      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('timeout') ||
          e.toString().toLowerCase().contains('socket')) {
        _showConnectionErrorDialog();
      } else {
        _showGenericErrorDialog();
      }
    }
  }

  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.red),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Disconnected. Check your internet connection.',
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

  Future<void> _createJourneyPlan(int clientId, DateTime date,
      {String? notes}) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await ApiService.createJourneyPlan(
        clientId,
        date,
        notes: notes,
      );

      // Refresh journey plans after creating a new one
      final journeyPlans = await ApiService.fetchJourneyPlans();

      setState(() {
        _journeyPlans = journeyPlans;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey plan created successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create journey plan: ${e.toString()}')),
      );
    }
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

  void _showClientSelectionDialog() {
    DateTime selectedDate = DateTime.now();
    String searchQuery = '';
    List<Client> filteredClients = _clients;
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Journey Plan'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                        filteredClients = _clients.where((client) {
                          return client.name
                                  .toLowerCase()
                                  .contains(searchQuery) ||
                              (client.address ?? '')
                                  .toLowerCase()
                                  .contains(searchQuery);
                        }).toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or address',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 12.0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Client',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _clients.isEmpty
                        ? const Center(child: Text('No clients available'))
                        : filteredClients.isEmpty
                            ? const Center(
                                child: Text('No matching clients found'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredClients.length,
                                itemBuilder: (context, index) {
                                  final client = filteredClients[index];
                                  return ListTile(
                                    title: Text(client.name),
                                    subtitle: Text(client.address ?? ''),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _createJourneyPlan(
                                        client.id,
                                        selectedDate,
                                        notes: notesController.text.trim(),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToJourneyView(JourneyPlan journeyPlan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyView(
          journeyPlan: journeyPlan,
          onCheckInSuccess: (updatedPlan) {
            setState(() {
              final index =
                  _journeyPlans.indexWhere((p) => p.id == updatedPlan.id);
              if (index != -1) {
                _journeyPlans[index] = updatedPlan;
              }
              _activeVisit = updatedPlan;
            });
          },
        ),
      ),
    );
  }

  // Add date filtering methods
  List<JourneyPlan> _getFilteredPlans() {
    return _journeyPlans.where((plan) {
      if (_hiddenJourneyPlans.contains(plan.id)) {
        return false;
      }
      if (!_isCustomRange) {
        // Show only today's plans
        return plan.date.year == DateTime.now().year &&
            plan.date.month == DateTime.now().month &&
            plan.date.day == DateTime.now().day;
      } else {
        // Show plans within custom date range
        return plan.date
                .isAfter(_startDate.subtract(const Duration(days: 1))) &&
            plan.date.isBefore(_endDate.add(const Duration(days: 1)));
      }
    }).toList();
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomRange = true;
      });
    }
  }

  void _resetToToday() {
    setState(() {
      _isCustomRange = false;
      _startDate = DateTime.now();
      _endDate = DateTime.now();
    });
  }

  // Add this method to handle hiding journey plans
  void _hideJourneyPlan(int journeyPlanId) {
    setState(() {
      _hiddenJourneyPlans.add(journeyPlanId);
    });
    // Show a snackbar with undo option
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Journey Plans',
        actions: [
          // Date range selector
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
            onPressed: () => _showDateRangePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _currentPage = 1;
                _hasMoreData = true;
                _journeyPlans.clear();
              });
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading && _journeyPlans.isEmpty
          ? const JourneyPlansSkeleton()
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    // Date range header
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
                                    : 'Today\'s Plans',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isCustomRange)
                                TextButton.icon(
                                  icon: const Icon(Icons.today),
                                  label: const Text('Show Today'),
                                  onPressed: _resetToToday,
                                ),
                            ],
                          ),
                          if (_isCustomRange)
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
                    // List view
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            _currentPage = 1;
                            _hasMoreData = true;
                            _journeyPlans.clear();
                          });
                          await _loadData();
                        },
                        child: _getFilteredPlans().isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_location_alt_rounded,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    Text('No journey plans found'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                key: const PageStorageKey('journey_plans_list'),
                                itemCount: _getFilteredPlans().length +
                                    (_hasMoreData ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _getFilteredPlans().length) {
                                    return _isLoadingMore
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          )
                                        : const SizedBox.shrink();
                                  }

                                  final journeyPlan =
                                      _getFilteredPlans()[index];
                                  return RepaintBoundary(
                                    child: JourneyPlanItem(
                                      journeyPlan: journeyPlan,
                                      onTap: () =>
                                          _navigateToJourneyView(journeyPlan),
                                      onHide: journeyPlan.statusText ==
                                                  'Completed' &&
                                              journeyPlan.id != null
                                          ? () =>
                                              _hideJourneyPlan(journeyPlan.id!)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showClientSelectionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Extract journey plan item to a separate widget for better performance
class JourneyPlanItem extends StatelessWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback onTap;
  final VoidCallback? onHide;

  const JourneyPlanItem({
    super.key,
    required this.journeyPlan,
    required this.onTap,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = journeyPlan.statusText == 'Completed';

    Widget content = Opacity(
      opacity: isCompleted ? 0.5 : 1.0,
      child: Card(
        key: ValueKey('journey_plan_${journeyPlan.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: InkWell(
          onTap: isCompleted ? null : onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.store,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              journeyPlan.client.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy')
                                  .format(journeyPlan.date),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
            ),
          ),
        ),
      ),
    );

    // Wrap with Dismissible if the plan is completed
    if (isCompleted && onHide != null) {
      return Dismissible(
        key: ValueKey('dismissible_${journeyPlan.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: Colors.red,
          child: const Icon(
            Icons.visibility_off,
            color: Colors.white,
          ),
        ),
        onDismissed: (_) => onHide!(),
        child: content,
      );
    }

    return content;
  }
}
