// Enhanced Responsive Targets Dashboard Page
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
import 'package:woosh/widgets/skeleton_loader.dart';

// Import detail pages
import 'detail_pages/visit_targets_detail_page.dart';
import 'detail_pages/new_clients_detail_page.dart';
import 'detail_pages/product_sales_detail_page.dart';
import 'detail_pages/all_targets_detail_page.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  bool _isLoading = true;
  String? _errorMessage;
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Responsive breakpoints
  bool get _isTablet => MediaQuery.of(context).size.width >= 768;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;
  bool get _isSmallPhone => MediaQuery.of(context).size.width < 375;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  // [Previous methods remain the same - _loadDashboardData, _loadDailyVisitTargets, etc.]
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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

      if (mounted) {
        setState(() {
          _dailyVisitTargets = results[0];
          _newClientsProgress = results[1];
          _productSalesProgress = results[2];
          _isLoading = false;
        });
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

  String _getDateRangeLabel() {
    if (_selectedDateRange != null) {
      final formatter = DateFormat('MMM d');
      return '${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}';
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
}
