import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:woosh/utils/app_theme.dart' hide CreamGradientCard;
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/cream_gradient_card.dart';
import 'package:woosh/controllers/profile_controller.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({super.key});

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  final ProfileController _profileController = Get.find<ProfileController>();
  String _selectedPeriod = 'week';
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>>? _loginData;
  List<Map<String, dynamic>>? _journeyData;
  String? _userId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCustomDate = false;
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final _cache = <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _scrollController.addListener(_onScroll);
    _precacheData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _precacheData() async {
    if (_userId == null) return;

    // Precache next period's data
    final periods = ['today', 'week', 'month'];
    for (final period in periods) {
      if (period != _selectedPeriod) {
        final dateRange = _getDateRangeForPeriod(period);
        final cacheKey = '${_userId}_${dateRange['start']}_${dateRange['end']}';
        if (!_cache.containsKey(cacheKey)) {
          await _fetchAndCacheData(dateRange['start'] as String,
              dateRange['end'] as String, cacheKey);
        }
      }
    }
  }

  Future<void> _fetchAndCacheData(
      String startDate, String endDate, String cacheKey) async {
    try {
      final urlParams = '?startDate=$startDate&endDate=$endDate';
      final loginResponse = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/analytics/login-hours/$_userId$urlParams'),
        headers: await _getAuthHeaders(),
      );
      final journeyResponse = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/analytics/journey-visits/$_userId$urlParams'),
        headers: await _getAuthHeaders(),
      );

      if (loginResponse.statusCode == 200 &&
          journeyResponse.statusCode == 200) {
        _cache[cacheKey] = {
          'loginData': json.decode(loginResponse.body),
          'journeyData': json.decode(journeyResponse.body),
        };
      }
    } catch (e) {
      print('Error precaching data: $e');
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      // Simulate loading more data (replace with actual implementation)
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _hasMoreData = false; // Set to false if no more data
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Map<String, String> _getDateRangeForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        return {
          'start': DateFormat('yyyy-MM-dd').format(now),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': DateFormat('yyyy-MM-dd').format(startOfWeek),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return {
          'start': DateFormat('yyyy-MM-dd').format(startOfMonth),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      default:
        return {
          'start': DateFormat('yyyy-MM-dd').format(now),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
    }
  }

  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonUI() {
    return Column(
      children: [
        _buildSkeletonCard(),
        const SizedBox(height: 6),
        _buildSkeletonCard(),
        const SizedBox(height: 6),
        _buildSkeletonCard(),
        const SizedBox(height: 6),
        _buildSkeletonCard(),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonUI();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 11),
            GoldGradientButton(
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 8),
            _buildStatsCards(),
            if (_isLoadingMore) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  void _loadUserId() {
    final userData = GetStorage().read('salesRep');
    if (userData != null && userData['id'] != null) {
      setState(() => _userId = userData['id'].toString());
      _loadStats();
    } else {
      setState(() => _error = 'User ID not found');
    }
  }

  Future<void> _loadStats() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String urlParams = '';
      if (_isCustomDate && _startDate != null && _endDate != null) {
        final format = DateFormat('yyyy-MM-dd');
        urlParams =
            '?startDate=${format.format(_startDate!)}&endDate=${format.format(_endDate!)}';
      } else {
        final dateRange = _getDateRange();
        urlParams =
            '?startDate=${dateRange['start']}&endDate=${dateRange['end']}';
      }

      print('Fetching stats for user $_userId with params: $urlParams');

      // Clear cache for this specific key
      final cacheKey = '${_userId}_$urlParams';
      _cache.remove(cacheKey);

      // Load data in parallel
      final responses = await Future.wait([
        _retryOperation(
          () async => http.get(
            Uri.parse('${ApiService.baseUrl}/analytics/login-hours/$_userId'),
            headers: await _getAuthHeaders(),
          ),
          maxRetries: 3,
        ),
        _retryOperation(
          () async => http.get(
            Uri.parse(
                '${ApiService.baseUrl}/analytics/journey-visits/$_userId'),
            headers: await _getAuthHeaders(),
          ),
          maxRetries: 3,
        ),
      ]);

      final loginResponse = responses[0];
      final journeyResponse = responses[1];

      print('Login Hours Response Status: ${loginResponse.statusCode}');
      print('Journey Visits Response Status: ${journeyResponse.statusCode}');

      if (loginResponse.statusCode == 200 &&
          journeyResponse.statusCode == 200) {
        final loginData = json.decode(loginResponse.body);
        final journeyData = json.decode(journeyResponse.body);

        print('Raw Login Hours Data: ${json.encode(loginData)}');
        print('Raw Journey Visits Data: ${json.encode(journeyData)}');

        // Validate and process the data
        if (_isValidData(loginData) && _isValidJourneyData(journeyData)) {
          print('Data validation passed');

          // Cache the data
          _cache[cacheKey] = {
            'loginData': loginData,
            'journeyData': journeyData,
          };

          // Update UI in a single setState call
          setState(() {
            _loginData = [loginData];
            _journeyData = [journeyData];
            _isLoading = false;
          });

          // Print processed data
          final stats = _getFilteredStats();
          print('Processed Stats:');
          print('Formatted Duration: ${stats['formattedDuration']}');
          print('Total Hours: ${stats['totalHours']}');
          print('Total Minutes: ${stats['totalMinutes']}');
          print('Session Count: ${stats['sessionCount']}');
          print('Average Session Duration: ${stats['averageSessionDuration']}');
          print('Total Plans: ${stats['totalPlans']}');
          print('Completed Visits: ${stats['completedVisits']}');
          print('Pending Visits: ${stats['pendingVisits']}');
          print('Missed Visits: ${stats['missedVisits']}');
          print('Completion Rate: ${stats['completionRate']}');
          print('Client Visits: ${json.encode(stats['clientVisits'])}');
        } else {
          print('Data validation failed');
          print('Login Data Valid: ${_isValidData(loginData)}');
          print('Journey Data Valid: ${_isValidJourneyData(journeyData)}');
          throw Exception('Invalid data format received from server');
        }
      } else {
        final errorMessage = loginResponse.statusCode != 200
            ? 'Failed to load login hours: ${loginResponse.statusCode}'
            : 'Failed to load journey visits: ${journeyResponse.statusCode}';
        print('Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Exception caught: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<http.Response> _retryOperation(
    Future<http.Response> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      try {
        final response = await operation();
        if (response.statusCode == 200) {
          return response;
        }
        if (i < maxRetries - 1) {
          await Future.delayed(delay);
        }
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(delay);
      }
    }
    throw Exception('Failed after $maxRetries retries');
  }

  bool _isValidData(Map<String, dynamic> data) {
    final requiredFields = [
      'userId',
      'totalHours',
      'totalMinutes',
      'sessionCount',
      'formattedDuration',
      'averageSessionDuration'
    ];

    for (final field in requiredFields) {
      if (data[field] == null) {
        print('Missing required field: $field');
        return false;
      }
    }

    // Validate numeric fields
    if (data['totalHours'] is! int) {
      print('Invalid totalHours type: ${data['totalHours'].runtimeType}');
      return false;
    }
    if (data['totalMinutes'] is! int) {
      print('Invalid totalMinutes type: ${data['totalMinutes'].runtimeType}');
      return false;
    }
    if (data['sessionCount'] is! int) {
      print('Invalid sessionCount type: ${data['sessionCount'].runtimeType}');
      return false;
    }

    // Validate duration format
    if (data['formattedDuration'] is! String ||
        !RegExp(r'^\d+h \d+m$').hasMatch(data['formattedDuration'])) {
      print('Invalid formattedDuration: ${data['formattedDuration']}');
      return false;
    }

    // Validate average session duration format
    if (data['averageSessionDuration'] is! String ||
        !RegExp(r'^\d+m$').hasMatch(data['averageSessionDuration'])) {
      print(
          'Invalid averageSessionDuration: ${data['averageSessionDuration']}');
      return false;
    }

    return true;
  }

  bool _isValidJourneyData(Map<String, dynamic> data) {
    final requiredFields = [
      'userId',
      'totalPlans',
      'completedVisits',
      'pendingVisits',
      'missedVisits',
      'clientVisits',
      'completionRate'
    ];

    for (final field in requiredFields) {
      if (data[field] == null) {
        print('Missing required journey field: $field');
        return false;
      }
    }

    return true;
  }

  Map<String, String> _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        return {
          'start': DateFormat('yyyy-MM-dd').format(now),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': DateFormat('yyyy-MM-dd').format(startOfWeek),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return {
          'start': DateFormat('yyyy-MM-dd').format(startOfMonth),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
      default:
        return {
          'start': DateFormat('yyyy-MM-dd').format(now),
          'end': DateFormat('yyyy-MM-dd').format(now),
        };
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomDate = true;
      });
      _loadStats();
    }
  }

  Map<String, dynamic> _getFilteredStats() {
    if (_loginData == null || _journeyData == null) {
      return {
        'formattedDuration': '0h 0m',
        'completedVisits': 0,
        'completionRate': '0%',
        'averageSessionDuration': '0m',
        'totalHours': 0,
        'totalMinutes': 0,
        'sessionCount': 0,
        'totalPlans': 0,
        'pendingVisits': 0,
        'missedVisits': 0,
        'clientVisits': [],
      };
    }

    final loginStats = _loginData![0];
    final journeyStats = _journeyData![0];

    // Convert and validate numeric values
    final totalHours =
        loginStats['totalHours'] is int ? loginStats['totalHours'] : 0;
    final totalMinutes =
        loginStats['totalMinutes'] is int ? loginStats['totalMinutes'] : 0;
    final sessionCount =
        loginStats['sessionCount'] is int ? loginStats['sessionCount'] : 0;

    // Calculate correct total hours and minutes
    final totalMinutesFromHours = totalHours * 60;
    final totalMinutesCombined = totalMinutesFromHours + totalMinutes;
    final correctedHours = (totalMinutesCombined / 60).floor();
    final correctedMinutes = totalMinutesCombined % 60;

    // Format duration string correctly
    final formattedDuration = '$correctedHours ${correctedMinutes}m';

    // Calculate average session duration correctly
    final avgMinutes =
        sessionCount > 0 ? (totalMinutesCombined / sessionCount).round() : 0;
    final avgHours = (avgMinutes / 60).floor();
    final avgRemainingMinutes = avgMinutes % 60;
    final averageSessionDuration = avgHours > 0
        ? '${avgHours}h ${avgRemainingMinutes}m'
        : '${avgMinutes}m';

    return {
      'formattedDuration': formattedDuration,
      'completedVisits': journeyStats['completedVisits'],
      'completionRate': journeyStats['completionRate'],
      'averageSessionDuration': averageSessionDuration,
      'totalHours': correctedHours,
      'totalMinutes': correctedMinutes,
      'sessionCount': sessionCount,
      'totalPlans': journeyStats['totalPlans'],
      'pendingVisits': journeyStats['pendingVisits'],
      'missedVisits': journeyStats['missedVisits'],
      'clientVisits': journeyStats['clientVisits'],
      'totalMinutesCombined': totalMinutesCombined,
      'avgMinutes': avgMinutes,
    };
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Widget _buildPeriodSelector() {
    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today,
                  color: Theme.of(context).primaryColor, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Select Period',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('Today', 'today'),
                const SizedBox(width: 6),
                _buildPeriodChip('This Week', 'week'),
                const SizedBox(width: 6),
                _buildPeriodChip('This Month', 'month'),
                const SizedBox(width: 6),
                FilterChip(
                  selected: _isCustomDate,
                  label: Text(
                    _isCustomDate && _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                        : 'Custom Range',
                    style: TextStyle(
                      color: _isCustomDate ? Colors.white : Colors.black87,
                      fontSize: 11,
                    ),
                  ),
                  selectedColor: goldMiddle2,
                  backgroundColor: Colors.grey.shade200,
                  onSelected: (bool selected) {
                    if (selected) {
                      _selectDateRange(context);
                    } else {
                      setState(() {
                        _isCustomDate = false;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadStats();
                    }
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value && !_isCustomDate;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 11,
        ),
      ),
      selectedColor: goldMiddle2,
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
            _isCustomDate = false;
            _startDate = null;
            _endDate = null;
          });
          _loadStats();
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatsCards() {
    if (_isLoading) {
      return _buildSkeletonUI();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GoldGradientButton(
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_loginData == null || _journeyData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              'No data available for the selected period',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final stats = _getFilteredStats();

    return Column(
      children: [
        _buildStatCard(
          'Total Hours Worked',
          stats['formattedDuration'] ?? '0h 0m',
          Icons.access_time,
          Colors.blue,
          subtitle:
              '${stats['totalHours']}h ${stats['totalMinutes']}m across ${stats['sessionCount']} sessions',
        ),
        const SizedBox(height: 6),
        _buildStatCard(
          'Journey Plans',
          '${stats['totalPlans']}',
          Icons.map,
          Colors.green,
          subtitle:
              '${stats['completedVisits']} completed, ${stats['pendingVisits']} pending, ${stats['missedVisits']} missed',
        ),
        const SizedBox(height: 6),
        _buildStatCard(
          'Visit Completion Rate',
          stats['completionRate'] ?? '0%',
          Icons.analytics,
          Colors.orange,
          subtitle:
              '${stats['completedVisits']} of ${stats['totalPlans']} plans completed',
        ),
        const SizedBox(height: 6),
        _buildStatCard(
          'Average Session Duration',
          stats['averageSessionDuration'] ?? '0m',
          Icons.timer,
          Colors.purple,
          subtitle: 'Based on ${stats['sessionCount']} sessions',
        ),
        if (stats['clientVisits'] != null &&
            stats['clientVisits'].isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildClientVisitsCard(stats['clientVisits']),
        ],
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 20.0,
              lineWidth: 3.0,
              percent: 1.0,
              center: Icon(icon, color: color, size: 14),
              backgroundColor: color.withOpacity(0.2),
              progressColor: color,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientVisitsCard(List<dynamic> clientVisits) {
    // Sort client visits by visit count in descending order
    final sortedVisits = List.from(clientVisits)
      ..sort((a, b) => (b['visitCount'] ?? 0).compareTo(a['visitCount'] ?? 0));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Client Visits',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sortedVisits.map((client) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          client['clientName'] ?? 'Unknown Client',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${client['visitCount']} visits',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    print('Clearing all cached data');
    _cache.clear();
    setState(() {
      _loginData = null;
      _journeyData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'My Statistics',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _clearCache();
              await _loadStats();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
