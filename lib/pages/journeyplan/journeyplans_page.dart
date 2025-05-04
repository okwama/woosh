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
      final cachedPlans = ApiService.getCachedData<List<JourneyPlan>>(
          _journeyPlansCacheKey);
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
      final clients = await ApiService.fetchClients();
      final journeyPlans = await ApiService.fetchJourneyPlans(page: 1);

      if (mounted) {
        setState(() {
          _clients = clients;
          _journeyPlans = journeyPlans;
          _isLoading = false;
        });
        _cacheData(); // Cache the new data
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    }
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
    if (_activeVisit != null &&
        _activeVisit!.id != journeyPlan.id &&
        !_activeVisit!.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have an active visit at ${_activeVisit!.clientName}. Please complete it before starting a new one.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Journey Plans',
        actions: [
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
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _currentPage = 1;
                      _hasMoreData = true;
                      _journeyPlans.clear();
                    });
                    await _loadData();
                  },
                  child: _journeyPlans.isEmpty
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
                          itemCount:
                              _journeyPlans.length + (_hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _journeyPlans.length) {
                              return _isLoadingMore
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }

                            final journeyPlan = _journeyPlans[index];
                            return RepaintBoundary(
                              // Add repaint boundary for better performance
                              child: JourneyPlanItem(
                                journeyPlan: journeyPlan,
                                onTap: () =>
                                    _navigateToJourneyView(journeyPlan),
                              ),
                            );
                          },
                        ),
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

  const JourneyPlanItem({
    super.key,
    required this.journeyPlan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = journeyPlan.statusText == 'Completed';
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
  }
}
