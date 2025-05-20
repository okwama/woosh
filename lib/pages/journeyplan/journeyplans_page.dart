import 'package:flutter/material.dart';
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
import '../../services/hive/journey_plan_hive_service.dart';
import '../../models/hive/journey_plan_model.dart';


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
  final Set<int> _hiddenJourneyPlans = {};
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  JourneyPlan? _activeVisit;
  
  // Hive service for local storage
  final JourneyPlanHiveService _hiveService = JourneyPlanHiveService();

  // Date filtering state
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isCustomRange = false;
  bool _showFuturePlans = true; // New flag to show future plans

  @override
  void initState() {
    super.initState();
    _initHiveService();
    _loadData();
    _scrollController.addListener(_onScroll);
    _checkActiveVisit();
  }
  
  // Initialize Hive service
  Future<void> _initHiveService() async {
    try {
      await _hiveService.init();
      // Load cached journey plans after initializing Hive
      _loadCachedJourneyPlans();
    } catch (e) {
      print('Error initializing Hive service: $e');
    }
  }
  
  // Load journey plans from local Hive storage
  void _loadCachedJourneyPlans() {
    try {
      final cachedPlans = _hiveService.getAllJourneyPlans();
      if (cachedPlans.isNotEmpty) {
        // Convert Hive models to JourneyPlan objects
        final journeyPlans = cachedPlans.map((model) => _convertToJourneyPlan(model)).toList();
        setState(() {
          _journeyPlans = journeyPlans;
        });
        print('Loaded ${journeyPlans.length} journey plans from local storage');
      }
    } catch (e) {
      print('Error loading cached journey plans: $e');
    }
  }
  
  // Convert JourneyPlanModel (Hive) to JourneyPlan
  JourneyPlan _convertToJourneyPlan(JourneyPlanModel model) {
    // Find the client by ID or create a placeholder
    Client client = _findClientById(model.clientId);
    
    // Create a JourneyPlan from the model
    return JourneyPlan(
      id: model.id,
      date: model.date,
      time: model.time, // Time is required
      salesRepId: model.userId,
      status: model.status,
      routeId: model.routeId,
      client: client,
      showUpdateLocation: model.showUpdateLocation, // This is already non-null in the model
    );
  }
  
  // Find a client by ID or create a placeholder
  Client _findClientById(int clientId) {
    // Try to find the client in the loaded clients list
    try {
      return _clients.firstWhere((client) => client.id == clientId);
    } catch (e) {
      // Create a placeholder client with required fields
      return Client(
        id: clientId,
        name: 'Unknown Client',
        address: '',
        regionId: 0,
        region: '',
        countryId: 0,
      );
    }
  }
  
  // Convert JourneyPlan to JourneyPlanModel (Hive)
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
  
  // Save journey plans to Hive
  Future<void> _saveJourneyPlansToHive(List<JourneyPlan> journeyPlans) async {
    try {
      // Convert JourneyPlan objects to JourneyPlanModel objects
      final journeyPlanModels = journeyPlans.map(_convertToJourneyPlanModel).toList();
      
      // Save to Hive
      await _hiveService.saveJourneyPlans(journeyPlanModels);
      print('Saved ${journeyPlans.length} journey plans to local storage');
    } catch (e) {
      print('Error saving journey plans to Hive: $e');
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
        
        // Save the new journey plans to Hive
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
      final routeId = ApiService.getCurrentUserRouteId();
      final clientsResponse = await ApiService.fetchClients(routeId: routeId);
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);

      if (mounted) {
        setState(() {
          _clients = clientsResponse.data;
          _journeyPlans = journeyPlans;
          _isLoading = false;
        });
        
        // Save journey plans to Hive for offline access
        _saveJourneyPlansToHive(journeyPlans);
      }
    } catch (e) {
      print('Error loading data: $e');
      
      // If we have cached data, use it
      if (_journeyPlans.isEmpty) {
        _loadCachedJourneyPlans();
      }
      
      setState(() {
        _isLoading = false;
      });

      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('timeout')) {
        _showConnectionErrorDialog();
      } else {
        _showGenericErrorDialog();
      }
    }
  }

  List<JourneyPlan> _getFilteredPlans() {
    // Get current date in local timezone (Nairobi/EAT)
    final now = DateTime.now();
    // Create date-only version for comparison (no time component)
    final today = DateTime(now.year, now.month, now.day);
    
    return _journeyPlans.where((plan) {
      if (_hiddenJourneyPlans.contains(plan.id)) {
        return false;
      }
      
      // Always ensure we're working with local time
      final localPlanDate = plan.date.toLocal();
      // Create date-only version for comparison
      final planDateOnly = DateTime(
        localPlanDate.year,
        localPlanDate.month,
        localPlanDate.day
      );
      
      if (_isCustomRange) {
        // Create date-only versions of start/end dates
        final startDateOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final endDateOnly = DateTime(_endDate.year, _endDate.month, _endDate.day);
        
        // Compare only dates (no time component)
        return planDateOnly.isAtSameMomentAs(startDateOnly) || 
               planDateOnly.isAtSameMomentAs(endDateOnly) ||
               (planDateOnly.isAfter(startDateOnly) && 
                planDateOnly.isBefore(endDateOnly));
      } else {
        // Show today's and future plans by default
        return _showFuturePlans 
            ? planDateOnly.isAtSameMomentAs(today) || planDateOnly.isAfter(today)
            : planDateOnly.isAtSameMomentAs(today);
      }
    }).toList();
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

  void _navigateToCreateJourneyPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateJourneyPlanPage(
          clients: _clients,
          onSuccess: (updatedJourneyPlans) {
            // Save the newly created journey plan to Hive
            if (updatedJourneyPlans.isNotEmpty) {
              _saveJourneyPlansToHive(updatedJourneyPlans);
            }
            
            // Reload data to show the newly created journey plan
            _loadData();
            
            // Show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Journey plan created and saved locally')),
            );
          },
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

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
          // Toggle for showing future plans
          IconButton(
            icon: Icon(_showFuturePlans ? Icons.calendar_today : Icons.calendar_view_day),
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
                            itemCount: _getFilteredPlans().length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _getFilteredPlans().length) {
                                return _isLoadingMore
                                    ? const Center(child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ))
                                    : const SizedBox.shrink();
                              }

                              final journeyPlan = _getFilteredPlans()[index];
                              return JourneyPlanItem(
                                journeyPlan: journeyPlan,
                                onTap: () => _navigateToJourneyView(journeyPlan),
                                onHide: journeyPlan.statusText == 'Completed' && journeyPlan.id != null
                                    ? () => _hideJourneyPlan(journeyPlan.id!)
                                    : null,
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

// Journey plan item widget
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
                              // Convert to local time (Nairobi/EAT) before formatting
                              DateFormat('MMM dd, yyyy - HH:mm')
                                  .format(journeyPlan.date.toLocal()),
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