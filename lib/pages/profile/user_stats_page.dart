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
import 'package:woosh/services/token_service.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({super.key});

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  final ProfileController _profileController = Get.find<ProfileController>();
  bool _isLoading = false;
  String? _error;
  String? _userId;

  // Calendar related variables
  DateTime _focusedDay = DateTime.now();
  final DateTime _firstDay = DateTime.now().subtract(const Duration(days: 365));
  final DateTime _lastDay = DateTime.now().add(const Duration(days: 365));

  // Data storage
  final Map<DateTime, Map<String, dynamic>> _dailyStats = {};

  // Cache for API responses
  final Map<String, Map<String, dynamic>> _cache = {};

  // Loading states
  final Set<DateTime> _activeDays = {};

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  void _loadUserId() {
    final userData = GetStorage().read('salesRep');
    if (userData != null && userData['id'] != null) {
      setState(() => _userId = userData['id'].toString());
      _loadMonthData(_focusedDay);
    } else {
      setState(() => _error = 'User ID not found');
    }
  }

  // Load data for the entire month
  Future<void> _loadMonthData(DateTime month) async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final cacheKey = '${_userId}_${DateFormat('yyyy-MM').format(month)}';

      if (_cache.containsKey(cacheKey)) {
        _processCachedMonthData(_cache[cacheKey]!);
        setState(() => _isLoading = false);
        return;
      }

      final urlParams =
          '?startDate=${DateFormat('yyyy-MM-dd').format(startOfMonth)}&endDate=${DateFormat('yyyy-MM-dd').format(endOfMonth)}';

      final responses = await Future.wait([
        http.get(
          Uri.parse(
              '${ApiService.baseUrl}/analytics/daily-login-hours/$_userId$urlParams'),
          headers: await _getAuthHeaders(),
        ),
        http.get(
          Uri.parse(
              '${ApiService.baseUrl}/targets/monthly-visits/$_userId$urlParams'),
          headers: await _getAuthHeaders(),
        ),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final loginData = json.decode(responses[0].body);
        final journeyData = json.decode(responses[1].body);

        final monthData = {
          'loginData': loginData,
          'journeyData': journeyData,
        };

        _cache[cacheKey] = monthData;
        _processCachedMonthData(monthData);
      } else {
        throw Exception('Failed to load month data');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processCachedMonthData(Map<String, dynamic> monthData) {
    // Handle different possible response structures
    dynamic loginDataRaw = monthData['loginData'];
    dynamic journeyDataRaw = monthData['journeyData'];

    // Convert to List<dynamic> safely
    List<dynamic> loginData = [];
    List<dynamic> journeyData = [];

    if (loginDataRaw is List) {
      loginData = loginDataRaw;
    } else if (loginDataRaw is Map) {
      // If it's a map, try to extract data from it
      if (loginDataRaw.containsKey('data') && loginDataRaw['data'] is List) {
        loginData = loginDataRaw['data'];
      }
    }

    if (journeyDataRaw is List) {
      journeyData = journeyDataRaw;
    } else if (journeyDataRaw is Map) {
      // If it's a map, try to extract data from it
      if (journeyDataRaw.containsKey('data') &&
          journeyDataRaw['data'] is List) {
        journeyData = journeyDataRaw['data'];
      }
    }

    Map<DateTime, Map<String, dynamic>> newDailyStats = {};
    Set<DateTime> newActiveDays = {};

    // Process login data
    for (final dayData in loginData) {
      if (dayData is! Map<String, dynamic>) continue;

      final dateStr = dayData['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        final normalizedDate = DateTime(date.year, date.month, date.day);

        final totalMinutes = dayData['totalMinutes'] as int? ?? 0;
        final sessionCount = dayData['sessionCount'] as int? ?? 0;

        if (totalMinutes > 0 || sessionCount > 0) {
          newActiveDays.add(normalizedDate);
          newDailyStats[normalizedDate] = {
            'login': dayData,
            'journey': <String, dynamic>{},
          };
        }
      } catch (e) {
        print('Error parsing login data for date $dateStr: $e');
        continue;
      }
    }

    // Process journey data
    for (final dayData in journeyData) {
      if (dayData is! Map<String, dynamic>) continue;

      final dateStr = dayData['date'] as String?;
      if (dateStr == null) continue;

      try {
        final date = DateTime.parse(dateStr);
        final normalizedDate = DateTime(date.year, date.month, date.day);

        final totalPlans = dayData['totalPlans'] as int? ?? 0;

        if (totalPlans > 0) {
          newActiveDays.add(normalizedDate);
          if (newDailyStats.containsKey(normalizedDate)) {
            newDailyStats[normalizedDate]!['journey'] = dayData;
          } else {
            newDailyStats[normalizedDate] = {
              'login': <String, dynamic>{},
              'journey': dayData,
            };
          }
        }
      } catch (e) {
        print('Error parsing journey data for date $dateStr: $e');
        continue;
      }
    }

    setState(() {
      _dailyStats.addAll(newDailyStats);
      _activeDays.addAll(newActiveDays);
    });
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Color _getEventColor(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dayStats = _dailyStats[normalizedDay];

    if (dayStats == null) return Colors.transparent;

    final loginStats = dayStats['login'] as Map<String, dynamic>? ?? {};
    final journeyStats = dayStats['journey'] as Map<String, dynamic>? ?? {};

    final totalMinutes = loginStats['totalMinutes'] as int? ?? 0;
    final totalPlans = journeyStats['totalPlans'] as int? ?? 0;

    final hasLogin = totalMinutes > 0;
    final hasJourney = totalPlans > 0;

    if (hasLogin && hasJourney) return Colors.green;
    if (hasLogin) return Colors.blue;
    if (hasJourney) return Colors.orange;

    return Colors.transparent;
  }

  Widget _buildMonthGrid() {
    final daysInMonth =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(4.0),
      child: Column(
        children: [
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedDay =
                        DateTime(_focusedDay.year, _focusedDay.month - 1);
                  });
                  _loadMonthData(_focusedDay);
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedDay =
                        DateTime(_focusedDay.year, _focusedDay.month + 1);
                  });
                  _loadMonthData(_focusedDay);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          // Calendar grid
          ...List.generate((daysInMonth + firstWeekday - 2) ~/ 7 + 1,
              (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 2;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final day =
                    DateTime(_focusedDay.year, _focusedDay.month, dayNumber);
                final color = _getEventColor(day);
                final isToday = day.isAtSameMomentAs(DateTime.now());

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 40,
                    decoration: BoxDecoration(
                      color: color == Colors.transparent
                          ? Colors.grey.shade100
                          : color.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: goldMiddle2, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        dayNumber.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: color == Colors.transparent
                              ? Colors.grey.shade600
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.green, 'Login + Journey'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Login Only'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildLegendItem(Colors.orange, 'Journey Only'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.grey.shade100, 'No Activity'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildMonthSummary() {
    final totalDays = _activeDays.length;
    final totalLoginHours = _dailyStats.values.fold<int>(0, (sum, stats) {
      final loginData = stats['login'] as Map<String, dynamic>? ?? {};
      final minutes = loginData['totalMinutes'] as int? ?? 0;
      return sum + minutes;
    });
    final totalJourneyPlans = _dailyStats.values.fold<int>(0, (sum, stats) {
      final journeyData = stats['journey'] as Map<String, dynamic>? ?? {};
      final plans = journeyData['totalPlans'] as int? ?? 0;
      return sum + plans;
    });

    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics,
                  color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MMMM yyyy').format(_focusedDay)} Summary',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GoldGradientButton(
                onPressed: () => _navigateToMonthSummary(),
                child: const Text('View Details'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Active Days',
                  totalDays.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Hours',
                  '${(totalLoginHours / 60).floor()}h ${totalLoginHours % 60}m',
                  Icons.access_time,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Journey Plans',
                  totalJourneyPlans.toString(),
                  Icons.map,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt,
                  color: Theme.of(context).primaryColor, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Quick Navigation',
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
                _buildQuickFilterChip('This Month', () {
                  final now = DateTime.now();
                  setState(() {
                    _focusedDay = now;
                  });
                  _loadMonthData(now);
                }),
                const SizedBox(width: 6),
                _buildQuickFilterChip('Last Month', () {
                  final lastMonth =
                      DateTime(_focusedDay.year, _focusedDay.month - 1);
                  setState(() {
                    _focusedDay = lastMonth;
                  });
                  _loadMonthData(lastMonth);
                }),
                const SizedBox(width: 6),
                _buildQuickFilterChip('This Year', () {
                  final now = DateTime.now();
                  setState(() {
                    _focusedDay = now;
                  });
                  _loadMonthData(now);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: goldMiddle2.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: goldMiddle2.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: goldMiddle2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _navigateToMonthSummary() {
    // Navigate to month summary page
    Get.to(() => MonthSummaryPage(
          month: _focusedDay,
          userId: _userId!,
          dailyStats: _dailyStats,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'My Statistics',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _cache.clear();
              _dailyStats.clear();
              _activeDays.clear();
              _loadMonthData(_focusedDay);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      GoldGradientButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _loadMonthData(_focusedDay);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    children: [
                      _buildDateRangePicker(),
                      const SizedBox(height: 8),
                      _buildMonthSummary(),
                      const SizedBox(height: 8),
                      _buildMonthGrid(),
                      const SizedBox(height: 8),
                      _buildLegend(),
                    ],
                  ),
                ),
    );
  }
}

// Month Summary Page
class MonthSummaryPage extends StatefulWidget {
  final DateTime month;
  final String userId;
  final Map<DateTime, Map<String, dynamic>> dailyStats;

  const MonthSummaryPage({
    super.key,
    required this.month,
    required this.userId,
    required this.dailyStats,
  });

  @override
  State<MonthSummaryPage> createState() => _MonthSummaryPageState();
}

class _MonthSummaryPageState extends State<MonthSummaryPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _detailedStats;

  @override
  void initState() {
    super.initState();
    _loadDetailedStats();
  }

  Future<void> _loadDetailedStats() async {
    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
      final endOfMonth = DateTime(widget.month.year, widget.month.month + 1, 0);
      final urlParams =
          '?startDate=${DateFormat('yyyy-MM-dd').format(startOfMonth)}&endDate=${DateFormat('yyyy-MM-dd').format(endOfMonth)}';

      final responses = await Future.wait([
        http.get(
          Uri.parse(
              '${ApiService.baseUrl}/analytics/daily-login-hours/${widget.userId}$urlParams'),
          headers: await _getAuthHeaders(),
        ),
        http.get(
          Uri.parse(
              '${ApiService.baseUrl}/targets/monthly-visits/${widget.userId}$urlParams'),
          headers: await _getAuthHeaders(),
        ),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final loginDataRaw = json.decode(responses[0].body);
        final journeyDataRaw = json.decode(responses[1].body);

        // Handle different response structures
        Map<String, dynamic> loginData = {};
        Map<String, dynamic> journeyData = {};

        if (loginDataRaw is Map) {
          loginData = Map<String, dynamic>.from(loginDataRaw);
        } else if (loginDataRaw is List) {
          // If it's a list, create a summary map
          loginData = {
            'data': loginDataRaw,
            'totalMinutes': loginDataRaw.fold<int>(
                0,
                (sum, item) =>
                    sum +
                    (item is Map ? (item['totalMinutes'] as int? ?? 0) : 0)),
            'sessionCount': loginDataRaw.fold<int>(
                0,
                (sum, item) =>
                    sum +
                    (item is Map ? (item['sessionCount'] as int? ?? 0) : 0)),
          };
        }

        if (journeyDataRaw is Map) {
          journeyData = Map<String, dynamic>.from(journeyDataRaw);
        } else if (journeyDataRaw is List) {
          // If it's a list, create a summary map
          journeyData = {
            'data': journeyDataRaw,
            'totalPlans': journeyDataRaw.fold<int>(
                0,
                (sum, item) =>
                    sum +
                    (item is Map ? (item['totalPlans'] as int? ?? 0) : 0)),
          };
        }

        setState(() {
          _detailedStats = {
            'login': loginData,
            'journey': journeyData,
          };
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '${DateFormat('MMMM yyyy').format(widget.month)} Summary',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_detailedStats != null) ...[
                    _buildDetailedSummary(),
                    const SizedBox(height: 16),
                    _buildDailyBreakdown(),
                  ] else
                    const Center(
                      child: Text('No detailed data available'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailedSummary() {
    final loginStats = _detailedStats!['login'] as Map<String, dynamic>? ?? {};
    final journeyStats =
        _detailedStats!['journey'] as Map<String, dynamic>? ?? {};

    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Overview',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Hours',
                  loginStats['formattedDuration'] ?? '0h 0m',
                  Icons.access_time,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Sessions',
                  '${loginStats['sessionCount'] ?? 0}',
                  Icons.login,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Journey Plans',
                  '${journeyStats['totalPlans'] ?? 0}',
                  Icons.map,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Completed',
                  '${journeyStats['completedVisits'] ?? 0}',
                  Icons.check_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    final activeDays = widget.dailyStats.keys.toList()..sort();

    return CreamGradientCard(
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Breakdown',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...activeDays.map((day) {
            final stats = widget.dailyStats[day]!;
            final loginStats = stats['login'] as Map<String, dynamic>? ?? {};
            final journeyStats =
                stats['journey'] as Map<String, dynamic>? ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('MMM dd').format(day),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${loginStats['totalHours'] ?? 0}h ${loginStats['totalMinutes'] ?? 0}m',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${journeyStats['totalPlans'] ?? 0} plans',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
