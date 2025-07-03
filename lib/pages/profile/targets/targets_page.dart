// Enhanced Responsive Targets Dashboard Page
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:glamour_queen/models/target_model.dart';
import 'package:glamour_queen/models/order_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/target_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:get_storage/get_storage.dart';
<<<<<<< HEAD
import 'package:woosh/utils/app_theme.dart' hide CreamGradientCard;
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/cream_gradient_card.dart';
import 'package:woosh/widgets/skeleton_loader.dart';

// Import detail pages
import 'detail_pages/visit_targets_detail_page.dart';
import 'detail_pages/new_clients_detail_page.dart';
import 'detail_pages/product_sales_detail_page.dart';
import 'detail_pages/all_targets_detail_page.dart';
=======
import 'package:glamour_queen/utils/app_theme.dart' hide CreamGradientCard;
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/gradient_widgets.dart';
import 'package:glamour_queen/widgets/cream_gradient_card.dart';
import 'package:glamour_queen/pages/profile/targets/visits_tab.dart';
import 'package:glamour_queen/pages/profile/targets/orders_tab.dart';
import 'package:glamour_queen/pages/profile/targets/all_targets_tab.dart';
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  bool _isLoading = true;
  String? _errorMessage;
<<<<<<< HEAD
  String _selectedPeriod = 'current_month';
  DateTimeRange? _selectedDateRange;
  bool _showDateRangePicker = false;

  // Dashboard data
  Map<String, dynamic> _dashboardData = {};
  Map<String, dynamic> _dailyVisitTargets = {};
  Map<String, dynamic> _newClientsProgress = {};
  Map<String, dynamic> _productSalesProgress = {};

  final List<String> _periods = [
    'current_month',
    'last_month',
    'current_year',
    'custom_range',
  ];

  final Map<String, String> _periodLabels = {
    'current_month': 'This Month',
    'last_month': 'Last Month',
    'current_year': 'This Year',
    'custom_range': 'Custom Range',
  };
=======
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
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadDashboardData();
=======
    _tabController = TabController(length: 3, vsync: this);
    _loadTargets();
    _loadUserOrders();
    _loadDailyVisitTargets();
    _scrollController.addListener(_onScroll);
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  }

  // Responsive breakpoints
  bool get _isTablet => MediaQuery.of(context).size.width >= 768;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;
  bool get _isSmallPhone => MediaQuery.of(context).size.width < 375;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

<<<<<<< HEAD
  // [Previous methods remain the same - _loadDashboardData, _loadDailyVisitTargets, etc.]
  Future<void> _loadDashboardData() async {
=======
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
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
<<<<<<< HEAD
      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final results = await Future.wait([
        _loadDailyVisitTargets(userId),
        _loadNewClientsProgress(userId),
        _loadProductSalesProgress(userId),
      ]).timeout(
        Duration(seconds: 15),
        onTimeout: () => throw Exception(
            'Request timed out. Please check your internet connection.'),
      );

=======
      final targets = await TargetService.getTargets(
        page: _currentPage,
        limit: 10,
        startDate: _startDate,
        endDate: _endDate,
      );
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      if (mounted) {
        setState(() {
          _dailyVisitTargets = results[0];
          _newClientsProgress = results[1];
          _productSalesProgress = results[2];
          _isLoading = false;
        });
<<<<<<< HEAD
=======
        _precacheNextTargets();
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadDailyVisitTargets(String userId) async {
    try {
      final date = DateTime.now();
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      return await TargetService.getDailyVisitTargets(
        userId: userId,
        date: formattedDate,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => {
          'visitTarget': 0,
          'completedVisits': 0,
          'progress': 0,
          'status': 'Timeout',
        },
      );
    } catch (e) {
      return {
        'visitTarget': 0,
        'completedVisits': 0,
        'progress': 0,
        'status': 'Error',
      };
    }
  }

  Future<Map<String, dynamic>> _loadNewClientsProgress(String userId) async {
    try {
<<<<<<< HEAD
      String? startDateStr;
      String? endDateStr;

      if (_selectedDateRange != null) {
        startDateStr =
            DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        endDateStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }

      final result = await TargetService.getNewClientsProgress(
        int.parse(userId),
        period: _selectedPeriod,
        startDate: startDateStr,
        endDate: endDateStr,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('New clients request timed out'),
      );
      return result.toJson();
=======
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
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    } catch (e) {
      return {
        'newClientsTarget': 0,
        'newClientsAdded': 0,
        'progress': 0,
        'status': 'Error',
      };
    }
  }

  Future<Map<String, dynamic>> _loadProductSalesProgress(String userId) async {
    try {
      String? startDateStr;
      String? endDateStr;

      if (_selectedDateRange != null) {
        startDateStr =
            DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        endDateStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }

      final result = await TargetService.getProductSalesProgress(
        int.parse(userId),
        period: _selectedPeriod,
        startDate: startDateStr,
        endDate: endDateStr,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Product sales request timed out'),
      );
      return result.toJson();
    } catch (e) {
      return {
        'summary': {
          'vapes': {'progress': 0},
          'pouches': {'progress': 0},
        },
        'status': 'Error',
      };
    }
  }

  void _changePeriod(String period) {
    if (period != _selectedPeriod) {
      setState(() {
        _selectedPeriod = period;
        if (period == 'custom_range') {
          _showDateRangePicker = true;
        }
      });

      if (period == 'custom_range') {
        _showCustomDateRangePicker();
      } else {
        _selectedDateRange = null;
        _loadDashboardData();
      }
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _showDateRangePicker = false;
      });
      _loadDashboardData();
    } else {
      setState(() {
        _selectedPeriod = 'current_month';
        _showDateRangePicker = false;
      });
    }
  }

<<<<<<< HEAD
  String _getDateRangeLabel() {
    if (_selectedDateRange != null) {
      final formatter = DateFormat('MMM d');
      return '${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}';
=======
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
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    }
    return _periodLabels[_selectedPeriod] ?? _selectedPeriod;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) {
      return Colors.green;
    } else if (progress >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      backgroundColor: Colors.grey[50],
      appBar: _buildResponsiveAppBar(),
      body: Column(
        children: [
          _buildEnhancedHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: Theme.of(context).primaryColor,
              child: _isLoading
                  ? _buildEnhancedLoadingState()
                  : _errorMessage != null
                      ? _buildEnhancedErrorState()
                      : _buildResponsiveDashboardContent(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar() {
    return GradientAppBar(
      title: 'Performance Dashboard',
      elevation: 0,
      actions: [
        if (_isTablet) ...[
          Container(
            margin: EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _loadDashboardData,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, size: 22),
              onPressed: _isLoading ? null : _loadDashboardData,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_isTablet ? 24 : 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: _isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getDateRangeLabel(),
                        style: TextStyle(
                          fontSize: _isTablet ? 16 : 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isTablet ? 16 : 12,
                    vertical: _isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: _isTablet ? 18 : 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Live Data',
                        style: TextStyle(
                          fontSize: _isTablet ? 14 : 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: _isTablet ? 20 : 16),
            _buildEnhancedPeriodSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: _isTablet
          ? _buildTabletPeriodSelector()
          : _buildMobilePeriodSelector(),
    );
  }

  Widget _buildTabletPeriodSelector() {
    return Row(
      children: _periods.map((period) {
        final isSelected = period == _selectedPeriod;
        return Expanded(
          child: GestureDetector(
            onTap: () => _changePeriod(period),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                _selectedPeriod == 'custom_range' && _selectedDateRange != null
                    ? 'Custom'
                    : _periodLabels[period]!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobilePeriodSelector() {
    return Row(
      children: _periods.map((period) {
        final isSelected = period == _selectedPeriod;
        return Expanded(
          child: GestureDetector(
            onTap: () => _changePeriod(period),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 1),
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getShortPeriodLabel(period),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: _isSmallPhone ? 11 : 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getShortPeriodLabel(String period) {
    if (_selectedPeriod == 'custom_range' && _selectedDateRange != null) {
      return 'Custom';
    }

    switch (period) {
      case 'current_month':
        return 'Month';
      case 'last_month':
        return 'Last';
      case 'current_year':
        return 'Year';
      case 'custom_range':
        return 'Custom';
      default:
        return period;
    }
  }

  Widget _buildEnhancedLoadingState() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: _buildResponsiveGrid(
        children: List.generate(4, (index) => _buildLoadingSkeleton()),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 80, height: 16),
                SkeletonLoader(width: 40, height: 20, radius: 10),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SkeletonLoader(
                  width: 80,
                  height: 80,
                  radius: 40,
                ),
              ),
            ),
            SizedBox(height: 16),
            SkeletonLoader(width: 100, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: _isTablet ? 64 : 48,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: _isTablet ? 24 : 20,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'We couldn\'t load your dashboard data. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: _isTablet ? 16 : 14,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: Icon(Icons.refresh, size: 20),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 32 : 24,
                  vertical: _isTablet ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveDashboardContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AnimationLimiter(
        child: _buildResponsiveGrid(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 20.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              _buildEnhancedVisitTargetsCard(),
              _buildEnhancedNewClientsCard(),
              _buildEnhancedProductSalesCard(),
              _buildEnhancedAllTargetsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveGrid({required List<Widget> children}) {
    if (_isDesktop) {
      return GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
        padding: EdgeInsets.only(top: 8),
        children: children,
      );
    } else if (_isTablet) {
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
        padding: EdgeInsets.only(top: 8),
        children: children,
      );
    } else {
      return GridView.count(
        crossAxisCount: _isSmallPhone ? 1 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: _isSmallPhone ? 1.2 : 0.85,
        padding: EdgeInsets.only(top: 8),
        children: children,
      );
    }
  }

  Widget _buildEnhancedVisitTargetsCard() {
    final visitTarget = _dailyVisitTargets['visitTarget'] ?? 0;
    final completedVisits = _dailyVisitTargets['completedVisits'] ?? 0;
    final progress = _dailyVisitTargets['progress'] ?? 0;
    final normalizedProgress = (progress / 100).clamp(0.0, 1.0);

    return _buildEnhancedTargetCard(
      title: 'Daily Visits',
      subtitle: 'Location tracking',
      icon: Icons.location_on_outlined,
      color: Colors.blue,
      progress: normalizedProgress,
      currentValue: completedVisits.toString(),
      targetValue: visitTarget.toString(),
      trend: _getTrendIcon(normalizedProgress),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitTargetsDetailPage(
            period: _selectedPeriod,
            initialData: _dailyVisitTargets,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedNewClientsCard() {
    Map<String, dynamic> data;
    if (_newClientsProgress is Map) {
      data = Map<String, dynamic>.from(_newClientsProgress);
    } else {
      data = _newClientsProgress;
    }

    final target = data['newClientsTarget'] ?? 0;
    final added = data['newClientsAdded'] ?? 0;
    final progress = data['progress'] ?? 0;
    final normalizedProgress = (progress / 100).clamp(0.0, 1.0);

    return _buildEnhancedTargetCard(
      title: 'New Clients',
      subtitle: 'Acquisition',
      icon: Icons.person_add_outlined,
      color: Colors.green,
      progress: normalizedProgress,
      currentValue: added.toString(),
      targetValue: target.toString(),
      trend: _getTrendIcon(normalizedProgress),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewClientsDetailPage(
            period: _selectedPeriod,
            initialData: _newClientsProgress,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProductSalesCard() {
    final summary = _productSalesProgress['summary'] ?? {};
    final vapes = summary['vapes'] ?? {};
    final pouches = summary['pouches'] ?? {};
    final vapesProgress = vapes['progress'] ?? 0;
    final pouchesProgress = pouches['progress'] ?? 0;
    final overallProgress = ((vapesProgress + pouchesProgress) / 2) / 100;

    return _buildEnhancedTargetCard(
      title: 'Product Sales',
      subtitle: 'Revenue tracking',
      icon: Icons.inventory_2_outlined,
      color: Colors.purple,
      progress: overallProgress,
      currentValue: '${(overallProgress * 100).toInt()}%',
      targetValue: '100%',
      trend: _getTrendIcon(overallProgress),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductSalesDetailPage(
            period: _selectedPeriod,
            initialData: _productSalesProgress,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAllTargetsCard() {
    return _buildEnhancedTargetCard(
      title: 'All Targets',
      subtitle: 'Complete overview',
      icon: Icons.dashboard_outlined,
      color: Colors.teal,
      progress: 0.75,
      currentValue: '3',
      targetValue: '4',
      trend: _getTrendIcon(0.75),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllTargetsDetailPage(
            period: _selectedPeriod,
          ),
        ),
      ),
    );
  }

  Widget _getTrendIcon(double progress) {
    if (progress >= 0.8) {
      return Icon(Icons.trending_up, color: Colors.green, size: 16);
    } else if (progress >= 0.5) {
      return Icon(Icons.trending_flat, color: Colors.orange, size: 16);
    } else {
      return Icon(Icons.trending_down, color: Colors.red, size: 16);
    }
  }

  Widget _buildEnhancedTargetCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double progress,
    required String currentValue,
    required String targetValue,
    required Widget trend,
    required VoidCallback onTap,
  }) {
    final cardPadding = _isTablet ? 20.0 : 16.0;
    final borderRadius = _isTablet ? 20.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(_isTablet ? 10 : 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: _isTablet ? 20 : 18,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _isTablet ? 10 : 8),

                  // Title and subtitle
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _isTablet ? 15 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _isTablet ? 11 : 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: _isTablet ? 10 : 8),
                        child: CircularPercentIndicator(
                          radius: _isTablet ? 40 : 32,
                          lineWidth: _isTablet ? 8 : 6,
                          percent: progress,
                          center: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentValue,
                                style: TextStyle(
                                  fontSize: _isTablet ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'of $targetValue',
                                style: TextStyle(
                                  fontSize: _isTablet ? 11 : 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          progressColor: _getProgressColor(progress),
                          backgroundColor: Colors.grey[200]!,
                          circularStrokeCap: CircularStrokeCap.round,
                          animation: true,
                          animationDuration: 1200,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getProgressColor(progress).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getProgressColor(progress).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTrendIconData(progress),
                        color: _getProgressColor(progress),
                        size: 14,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: _isTablet ? 11 : 10,
                          fontWeight: FontWeight.w600,
                          color: _getProgressColor(progress),
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTrendIconData(double progress) {
    if (progress >= 0.8) {
      return Icons.trending_up;
    } else if (progress >= 0.5) {
      return Icons.trending_flat;
    } else {
      return Icons.trending_down;
    }
  }
=======
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
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
}

