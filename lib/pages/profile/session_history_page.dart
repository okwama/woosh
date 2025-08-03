import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/session_model.dart';
import 'package:woosh/services/clockInOut/clock_in_out_service.dart';
import 'package:woosh/utils/app_theme.dart' hide CreamGradientCard;
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/cream_gradient_card.dart';
import 'package:intl/intl.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage>
    with TickerProviderStateMixin {
  List<Session> _sessions = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCustomDate = false;
  String _selectedPeriod = 'week';
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final _cache = <String, List<Session>>{};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadUserId();
    _scrollController.addListener(_onScroll);
    _precacheData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadUserId() {
    final userData = GetStorage().read('salesRep');
    if (userData != null && userData['id'] != null) {
      if (mounted) {
        setState(() => _userId = userData['id'].toString());
        _loadSessions();
      }
    } else {
      if (mounted) {
        setState(() => _error = 'User ID not found');
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreSessions();
    }
  }

  Future<void> _precacheData() async {
    if (_userId == null) return;

    final periods = ['today', 'week', 'month'];
    for (final period in periods) {
      if (period != _selectedPeriod) {
        final dateRange = _getDateRangeForPeriod(period);
        final cacheKey = '${_userId}_${dateRange['start']}_${dateRange['end']}';
        if (!_cache.containsKey(cacheKey)) {
          await _fetchAndCacheData(
              dateRange['start']!, dateRange['end']!, cacheKey);
        }
      }
    }
  }

  Future<void> _fetchAndCacheData(
      String startDate, String endDate, String cacheKey) async {
    try {
      final response = await ClockInOutService.getClockHistory(
        _userId!,
        startDate: startDate,
        endDate: endDate,
      );

      if (response['sessions'] != null) {
        _cache[cacheKey] = (response['sessions'] as List)
            .map((session) => Session.fromJson(session))
            .toList();
      }
    } catch (e) {
      print('Error precaching data: $e');
    }
  }

  List<Session> _filterSessionsByDate(
      List<Session> sessions, DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return sessions;

    return sessions.where((session) {
      if (session.sessionStart == null) return false;
      try {
        final sessionDate = DateTime.parse(session.sessionStart!);
        return sessionDate
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            sessionDate.isBefore(endDate.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<void> _loadSessions() async {
    if (_userId == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Fetching clock history for user ID: $_userId');
      final response = await ClockInOutService.getClockHistory(_userId!);

      if (!mounted) return;

      print('Raw API Response:');
      print(response);
      print('Total sessions in response: ${response['sessions']?.length ?? 0}');

      if (response['sessions'] != null) {
        final allSessions = (response['sessions'] as List)
            .map((session) => Session.fromJson(session))
            .toList();

        print('Parsed sessions: ${allSessions.length}');

        final filteredSessions = _filterSessionsByDate(
          allSessions,
          _isCustomDate ? _startDate : _getStartDateForPeriod(_selectedPeriod),
          _isCustomDate ? _endDate : DateTime.now(),
        );

        print('Filtered sessions: ${filteredSessions.length}');

        if (mounted) {
          setState(() {
            _sessions = filteredSessions;
            _isLoading = false;
          });

          if (_animationController.status != AnimationStatus.completed) {
            _animationController.forward();
          }
        }
      } else {
        print('No sessions data in response');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading sessions: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMoreData || !mounted) return;

    setState(() => _isLoadingMore = true);

    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
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

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomDate = true;
      });
      _loadSessions();
    }
  }

  Map<String, String> _getDateRangeForPeriod(String period) {
    // Use Africa/Nairobi (EAT) timezone for 'today' calculations
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
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

  DateTime? _getStartDateForPeriod(String period) {
    // Use Africa/Nairobi (EAT) timezone for 'today' calculations
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    switch (period) {
      case 'today':
        return now;
      case 'week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'month':
        return DateTime(now.year, now.month, 1);
      default:
        return null;
    }
  }

  Widget _buildPeriodChip(String label, String value, IconData icon) {
    final isSelected = _selectedPeriod == value && !_isCustomDate;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selectedColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        elevation: isSelected ? 2 : 0,
        pressElevation: 4,
        onSelected: (bool selected) {
          if (selected && mounted) {
            setState(() {
              _selectedPeriod = value;
              _isCustomDate = false;
              _startDate = null;
              _endDate = null;
            });
            _loadSessions();
          }
        },
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildCompactSessionCard(Session session, int index) {
    final startTime = session.sessionStart ?? 'N/A';
    DateTime? startDateTime;
    String date = 'N/A';
    String timeStart = 'N/A';

    if (startTime != 'N/A') {
      try {
        startDateTime = DateTime.parse(startTime);
        date = DateFormat('MMM dd').format(startDateTime);
        timeStart = DateFormat('h:mm').format(startDateTime);
      } catch (e) {
        print('Error parsing start time: $e');
      }
    }

    String? timeEnd;
    String duration = _formatDuration(session.duration);
    Color durationColor = Colors.green;

    if (session.sessionEnd != null) {
      try {
        final endDateTime = DateTime.parse(session.sessionEnd!);
        timeEnd = DateFormat('h:mm').format(endDateTime);
      } catch (e) {
        print('Error parsing end time: $e');
      }
    }

    final isActive = session.status == '1';
    final statusColor = _getStatusColor(session);

    // Set duration color based on status
    if (session.status == '2') {
      durationColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Add tap functionality if needed
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Date section
                SizedBox(
                  width: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        startDateTime != null
                            ? DateFormat('EEE').format(startDateTime)
                            : 'N/A',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Time section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeStart,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (timeEnd != null)
                        Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 14,
                              color: Colors.red[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeEnd,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Duration and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: durationColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        duration,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: durationColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Ended',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
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
        ),
      ),
    );
  }

  Color _getStatusColor(Session session) {
    switch (session.status) {
      case '1':
        return Colors.green;
      case '2':
        return Colors.grey[600]!;
      default:
        return Colors.blue;
    }
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration == 'Active') return 'Active';
    
    // Handle negative durations
    if (duration.startsWith('-')) {
      return duration;
    }
    
    // Parse the duration string (e.g., "0h 0.16666666666666666m")
    try {
      final parts = duration.split(' ');
      if (parts.length >= 2) {
        final hours = parts[0].replaceAll('h', '');
        final minutes = parts[1].replaceAll('m', '');
        
        final hoursInt = int.tryParse(hours) ?? 0;
        final minutesDouble = double.tryParse(minutes) ?? 0.0;
        
        // Round minutes to 2 decimal places
        final roundedMinutes = (minutesDouble * 100).round() / 100;
        
        return '${hoursInt}h ${roundedMinutes.toStringAsFixed(2)}m';
      }
    } catch (e) {
      print('Error formatting duration: $e');
    }
    
    return duration;
  }

  Widget _buildCompactDateFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Filter Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                '${_sessions.length} sessions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('Today', 'today', Icons.today_rounded),
                _buildPeriodChip('Week', 'week', Icons.date_range_rounded),
                _buildPeriodChip(
                    'Month', 'month', Icons.calendar_month_rounded),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _isCustomDate,
                    avatar: Icon(
                      Icons.edit_calendar_rounded,
                      size: 14,
                      color: _isCustomDate ? Colors.white : Colors.grey[600],
                    ),
                    label: Text(
                      _isCustomDate && _startDate != null && _endDate != null
                          ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                          : 'Custom',
                      style: TextStyle(
                        color: _isCustomDate ? Colors.white : Colors.grey[700],
                        fontSize: 12,
                        fontWeight:
                            _isCustomDate ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selectedColor: Theme.of(context).primaryColor,
                    backgroundColor: Colors.grey[100],
                    checkmarkColor: Colors.white,
                    elevation: _isCustomDate ? 2 : 0,
                    pressElevation: 4,
                    onSelected: (bool selected) {
                      if (selected) {
                        _selectDateRange(context);
                      } else if (mounted) {
                        setState(() {
                          _isCustomDate = false;
                          _startDate = null;
                          _endDate = null;
                        });
                        _loadSessions();
                      }
                    },
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Sessions Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No sessions found for the selected period.\nTry selecting a different time range.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: GradientAppBar(
        title: 'Session History',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _error != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GoldGradientButton(
                          onPressed: _loadSessions,
                          child: const Text(
                            'Try Again',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  color: Theme.of(context).primaryColor,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildCompactDateFilter(),
                      ),
                      if (_sessions.isEmpty)
                        SliverFillRemaining(
                          child: _buildEmptyState(),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildCompactSessionCard(
                                    _sessions[index], index),
                              );
                            },
                            childCount: _sessions.length,
                          ),
                        ),
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                ),
    );
  }
}
