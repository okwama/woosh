// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:glamour_queen/models/target_model.dart';
import 'package:glamour_queen/models/order_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/target_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/utils/app_theme.dart' hide CreamGradientCard;
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/gradient_widgets.dart';
import 'package:glamour_queen/widgets/cream_gradient_card.dart';
import 'package:glamour_queen/pages/profile/targets/visits_tab.dart';
import 'package:glamour_queen/pages/profile/targets/orders_tab.dart';
import 'package:glamour_queen/pages/profile/targets/all_targets_tab.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Target> _targets = [];
  List<Order> _userOrders = [];
  bool _isLoading = true;
  bool _isLoadingOrders = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _sortOption = 'endDate';
  int _totalItemsSold = 0;
  final DateTime _twoWeeksAgo =
      DateTime.now().subtract(const Duration(days: 14));
  static const int _prefetchThreshold = 200;
  static const int _precachePages = 2;
  int _currentPage = 1;
  bool _hasMoreOrders = true;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _dailyVisitTargets = {};
  bool _isLoadingDailyVisits = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTargets();
    _loadUserOrders();
    _loadDailyVisitTargets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _prefetchThreshold) {
      if (!_isLoadingMore && _hasMoreOrders) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
      helpText: 'Select Date Range',
      cancelText: 'Cancel',
      confirmText: 'Select',
      saveText: 'Save',
      errorFormatText: 'Invalid date format',
      errorInvalidText: 'Invalid date range',
      errorInvalidRangeText: 'Invalid date range',
      fieldStartHintText: 'Start',
      fieldEndHintText: 'End',
      fieldStartLabelText: 'Start date',
      fieldEndLabelText: 'End date',
    );

    if (picked != null) {
      setState(() {
        _startDate =
            DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _refreshData();
    }
  }

  Future<void> _showYearPicker() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              selectedDate: _startDate ?? DateTime.now(),
              onChanged: (DateTime dateTime) {
                Navigator.pop(context, dateTime);
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, 1, 1);
        _endDate = DateTime(picked.year, 12, 31, 23, 59, 59);
      });
      _refreshData();
    }
  }

  Future<void> _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    return _refreshData();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final targets = await TargetService.getTargets(
        page: _currentPage,
        limit: 10,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _targets = targets;
          _isLoading = false;
        });
        _precacheNextTargets();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load targets: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _precacheNextTargets() async {
    try {
      // Precache next set of targets
      final nextTargets = await TargetService.getTargets(
        page: _currentPage + 1,
        limit: 10,
      );

      if (mounted && nextTargets.isNotEmpty) {
        ApiService.cacheData(
          'targets_page_${_currentPage + 1}',
          nextTargets,
          validity: const Duration(minutes: 5),
        );
      }
    } catch (e) {
      print('Precaching targets failed: $e');
    }
  }

  Future<void> _loadUserOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final cachedData =
          ApiService.getCachedData<Map<String, dynamic>>('sales_data');

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _totalItemsSold = cachedData['totalItemsSold'];
            _userOrders = (cachedData['recentOrders'] as List)
                .map((item) => Order.fromJson(item))
                .toList();
            _isLoadingOrders = false;
          });
        }
        return;
      }

      final salesData = await TargetService.getSalesData(
        page: _currentPage,
        limit: 10,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _totalItemsSold = salesData['totalItemsSold'];
          _userOrders = (salesData['recentOrders'] as List)
              .map((item) => Order.fromJson(item))
              .toList();
          _isLoadingOrders = false;
        });

        ApiService.cacheData(
          'sales_data',
          salesData,
          validity: const Duration(minutes: 5),
        );

        _precacheNextOrders();
      }
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreOrders) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Try to get cached data first
      final cachedData = ApiService.getCachedData<List<dynamic>>(
          'orders_page_${_currentPage + 1}');

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _userOrders.addAll(
              cachedData.map((item) => Order.fromJson(item)).toList(),
            );
            _currentPage++;
            _isLoadingMore = false;
            _hasMoreOrders = _currentPage < _precachePages + 1;
          });
        }
        return;
      }

      final salesData = await TargetService.getSalesData(
        page: _currentPage + 1,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _userOrders.addAll(
            (salesData['recentOrders'] as List)
                .map((item) => Order.fromJson(item))
                .toList(),
          );
          _currentPage++;
          _isLoadingMore = false;
          _hasMoreOrders = salesData['hasMore'];
        });

        // Cache the new data
        ApiService.cacheData(
          'orders_page_$_currentPage',
          salesData['recentOrders'],
          validity: const Duration(minutes: 5),
        );

        // Precache next pages
        _precacheNextOrders();
      }
    } catch (e) {
      print('Error loading more orders: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _precacheNextOrders() async {
    if (!_hasMoreOrders) return;

    final nextPage = _currentPage + 1;
    final endPage = nextPage + _precachePages;

    for (int page = nextPage; page < endPage; page++) {
      try {
        final salesData = await TargetService.getSalesData(
          page: page,
          limit: 10,
        );

        if (mounted && salesData['recentOrders'].isNotEmpty) {
          ApiService.cacheData(
            'orders_page_$page',
            salesData['recentOrders'],
            validity: const Duration(minutes: 5),
          );
        }
      } catch (e) {
        print('Precaching orders failed for page $page: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    // Clear existing cache
    for (int i = 1; i <= _precachePages; i++) {
      ApiService.removeFromCache('targets_page_$i');
      ApiService.removeFromCache('orders_page_$i');
    }
    ApiService.removeFromCache('sales_data');

    // Reset state
    setState(() {
      _currentPage = 1;
      _hasMoreOrders = true;
      _userOrders = [];
    });

    await Future.wait([
      _loadTargets(),
      _loadUserOrders(),
    ]);
  }

  Future<void> _loadDailyVisitTargets() async {
    setState(() {
      _isLoadingDailyVisits = true;
    });

    try {
      final box = GetStorage();
      final userId = box.read<String>('userId');
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final date = _startDate ?? DateTime.now();
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final visitData = await TargetService.getDailyVisitTargets(
        userId: userId,
        date: formattedDate,
      );

      if (mounted) {
        setState(() {
          _dailyVisitTargets = visitData;
          _isLoadingDailyVisits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load daily visit targets: $e';
          _isLoadingDailyVisits = false;
        });
      }
    }
  }

  // Filter targets by status
  List<Target> get _activeTargets =>
      _sortTargets(_targets.where((t) => t.isActive()).toList());

  List<Target> get _upcomingTargets => _sortTargets(_targets.where((t) {
        final now = DateTime.now();
        return now.isBefore(t.startDate) && !t.isCompleted;
      }).toList());

  List<Target> get _completedTargets =>
      _sortTargets(_targets.where((t) => t.isCompleted).toList());

  // Sort targets based on selected option
  List<Target> _sortTargets(List<Target> targets) {
    switch (_sortOption) {
      case 'endDate':
        targets.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case 'startDate':
        targets.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case 'progress':
        targets.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case 'title':
        targets.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'value':
        targets.sort((a, b) => b.targetValue.compareTo(a.targetValue));
        break;
    }
    return targets;
  }

  // Calculate summary metrics
  int get _totalTargets => _targets.length;
  int get _completedCount => _completedTargets.length;
  int get _activeCount => _activeTargets.length;
  int get _upcomingCount => _upcomingTargets.length;

  double get _overallProgress {
    if (_targets.isEmpty) return 0;
    int totalTargetValue = 0;
    int totalAchievedValue = 0;

    for (var target in _targets) {
      totalTargetValue += target.targetValue;
      totalAchievedValue += target.achievedValue;
    }

    return totalTargetValue > 0
        ? (totalAchievedValue / totalTargetValue) * 100
        : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Targets',
        actions: [
          if (_startDate != null && _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: 'Clear Date Range',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showYearPicker,
            tooltip: 'Select Year',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Column(
            children: [
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      if (_startDate?.year == _endDate?.year)
                        Text(
                          ' (${_startDate?.year})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    child: Text(
                      'Visits',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  // Tab(
                  //   child: Text(
                  //     'Orders',
                  //     style: TextStyle(color: Colors.white, fontSize: 12),
                  //   ),
                  // ),
                  Tab(
                    child: Text(
                      'All Targets',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: GradientCircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GoldGradientButton(
                        onPressed: _refreshData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    VisitsTab(
                      dailyVisitTargets: _dailyVisitTargets,
                      isLoadingDailyVisits: _isLoadingDailyVisits,
                      onRefresh: _refreshData,
                    ),
                   
                    AllTargetsTab(
                      targets: _targets,
                      userOrders: _userOrders,
                      isLoading: _isLoading,
                      isLoadingOrders: _isLoadingOrders,
                      dailyVisitTargets: _dailyVisitTargets,
                      isLoadingDailyVisits: _isLoadingDailyVisits,
                      totalItemsSold: _totalItemsSold,
                      onRefresh: _refreshData,
                    ),
                  ],
                ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Sort by'),
            enabled: false,
          ),
          ListTile(
            title: const Text('End Date'),
            leading: const Icon(Icons.calendar_today),
            selected: _sortOption == 'endDate',
            onTap: () {
              setState(() => _sortOption = 'endDate');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Start Date'),
            leading: const Icon(Icons.date_range),
            selected: _sortOption == 'startDate',
            onTap: () {
              setState(() => _sortOption = 'startDate');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Progress'),
            leading: const Icon(Icons.trending_up),
            selected: _sortOption == 'progress',
            onTap: () {
              setState(() => _sortOption = 'progress');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Title'),
            leading: const Icon(Icons.sort_by_alpha),
            selected: _sortOption == 'title',
            onTap: () {
              setState(() => _sortOption = 'title');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Target Value'),
            leading: const Icon(Icons.monetization_on),
            selected: _sortOption == 'value',
            onTap: () {
              setState(() => _sortOption = 'value');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

