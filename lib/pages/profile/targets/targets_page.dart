// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/target_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/target_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/utils/app_theme.dart' hide CreamGradientCard;
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/cream_gradient_card.dart';

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
  final DateTime _twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
  static const int _prefetchThreshold = 200;
  static const int _precachePages = 2;
  int _currentPage = 1;
  bool _hasMoreOrders = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTargets();
    _loadUserOrders();
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

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final targets = await TargetService.getTargets();
      if (mounted) {
        setState(() {
          _targets = targets;
          _isLoading = false;
        });
        // Precache next pages if available
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
      // Try to get cached data first
      final cachedData =
          ApiService.getCachedData<Map<String, dynamic>>('sales_data');

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _totalItemsSold = cachedData['totalItemsSold'];
            _userOrders = cachedData['recentOrders'];
            _isLoadingOrders = false;
          });
        }
        return;
      }

      final salesData = await TargetService.getSalesData();

      if (mounted) {
        setState(() {
          _totalItemsSold = salesData['totalItemsSold'];
          _userOrders = salesData['recentOrders'];
          _isLoadingOrders = false;
        });

        // Cache the sales data
        ApiService.cacheData(
          'sales_data',
          salesData,
          validity: const Duration(minutes: 5),
        );

        // Precache next pages of orders
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
      final cachedData = ApiService.getCachedData<List<Order>>(
          'orders_page_${_currentPage + 1}');

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _userOrders.addAll(cachedData);
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
          _userOrders.addAll(salesData['recentOrders']);
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
                child: Text('Active ($_activeCount)',
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
            Tab(
                child: Text('Upcoming ($_upcomingCount)',
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
            Tab(
                child: Text('Completed ($_completedCount)',
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
          ],
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
              : Column(
                  children: [
                    if (_targets.isNotEmpty) _buildSummaryCard(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTargetList(
                              _activeTargets, 'No active targets found'),
                          _buildTargetList(
                              _upcomingTargets, 'No upcoming targets found'),
                          _buildTargetList(
                              _completedTargets, 'No completed targets found'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard() {
    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.all(6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              'Products sold targets are tracked every two weeks',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 35.0,
                lineWidth: 8.0,
                percent: _overallProgress / 100,
                center: GradientText(
                  "${_overallProgress.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                backgroundColor: Colors.grey[300]!,
                progressColor: goldMiddle2,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 1500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatItem(Icons.check_circle, Colors.green,
                            _completedCount.toString(), 'Completed'),
                        _buildStatItem(Icons.pending, Colors.orange,
                            _activeCount.toString(), 'Active'),
                        _buildStatItem(Icons.upcoming, Colors.blue,
                            _upcomingCount.toString(), 'Upcoming'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
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

  Widget _buildTargetList(List<Target> targets, String emptyMessage) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 3,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildSkeletonCard(),
              ),
            ),
          );
        },
      );
    }

    if (targets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.track_changes, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: AnimationLimiter(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8.0),
          itemCount: targets.length + 1 + (_hasMoreOrders ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _isLoadingOrders
                  ? _buildSkeletonSalesCard()
                  : _buildSalesDataCard();
            }

            if (index == targets.length + 1) {
              return _isLoadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : const SizedBox.shrink();
            }

            final target = targets[index - 1];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildTargetCard(target),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSalesDataCard() {
    return Card(
      margin: const EdgeInsets.all(6.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart,
                    color: Theme.of(context).primaryColor, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Sales Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingOrders
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total items sold:',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalItemsSold items',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${_userOrders.length} orders',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                      if (_userOrders.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Recent Orders:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._userOrders.map((order) {
                          final orderData = order as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.shopping_bag,
                                    size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${orderData['totalItems']} items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('MMM d, yyyy').format(
                                    DateTime.parse(orderData['createdAt']),
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(Target target) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final progress = target.progress;
    final daysLeft = target.endDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 3.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    target.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: goldGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    target.typeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (target.description.isNotEmpty) ...[
              Text(
                target.description,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${dateFormatter.format(target.startDate)} - ${dateFormatter.format(target.endDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                const Spacer(),
                if (!target.isCompleted &&
                    !target.isOverdue() &&
                    daysLeft >= 0) ...[
                  Icon(Icons.timer, size: 12, color: Colors.blue[400]),
                  const SizedBox(width: 3),
                  Text(
                    '$daysLeft days left',
                    style: TextStyle(
                        color: Colors.blue[400],
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircularPercentIndicator(
                  radius: 20.0,
                  lineWidth: 4.0,
                  percent: progress / 100,
                  center: GradientText(
                    "${progress.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9.0,
                    ),
                  ),
                  progressColor: goldMiddle2,
                  backgroundColor: Colors.grey[300]!,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress: ${target.achievedValue} / ${target.targetValue}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      GradientLinearProgressIndicator(
                        value: progress / 100,
                        height: 6.0,
                        borderRadius: 3.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (target.isOverdue() && !target.isCompleted) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      'Overdue by ${DateTime.now().difference(target.endDate).inDays} days',
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 3.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 80,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 100,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonSalesCard() {
    return Card(
      margin: const EdgeInsets.all(6.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 150,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
