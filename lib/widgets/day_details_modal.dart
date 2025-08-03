import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_widgets.dart';

class DayDetailsModal extends StatefulWidget {
  final DateTime day;
  final String userId;
  final Map<String, dynamic>? dayStats;

  const DayDetailsModal({
    super.key,
    required this.day,
    required this.userId,
    this.dayStats,
  });

  @override
  State<DayDetailsModal> createState() => _DayDetailsModalState();
}

class _DayDetailsModalState extends State<DayDetailsModal> {
  bool _isLoading = false;
  Map<String, dynamic>? _detailedStats;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.dayStats != null) {
      _loadDetailedStats();
    }
  }

  Future<void> _loadDetailedStats() async {
    setState(() => _isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.day);
      final urlParams = '?startDate=$dateStr&endDate=$dateStr';

      final responses = await Future.wait([
        http.get(
          Uri.parse('${ApiService.baseUrl}/analytics/login-hours/${widget.userId}$urlParams'),
          headers: await _getAuthHeaders(),
        ),
        http.get(
          Uri.parse('${ApiService.baseUrl}/analytics/journey-visits/${widget.userId}$urlParams'),
          headers: await _getAuthHeaders(),
        ),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final loginData = json.decode(responses[0].body);
        final journeyData = json.decode(responses[1].body);

        setState(() {
          _detailedStats = {
            'login': loginData,
            'journey': journeyData,
          };
        });
      } else {
        setState(() => _error = 'Failed to load detailed stats');
      }
    } catch (e) {
      setState(() => _error = e.toString());
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

  Widget _buildQuickStats() {
    final loginStats = widget.dayStats?['login'] as Map<String, dynamic>? ?? {};
    final journeyStats = widget.dayStats?['journey'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        if (loginStats.isNotEmpty) ...[
          _buildQuickStatRow(
            'Hours Worked',
            '${loginStats['totalHours'] ?? 0}h ${loginStats['totalMinutes'] ?? 0}m',
            Icons.access_time,
            Colors.blue,
          ),
          const SizedBox(height: 8),
        ],
        if (journeyStats.isNotEmpty) ...[
          _buildQuickStatRow(
            'Journey Plans',
            '${journeyStats['totalPlans'] ?? 0}',
            Icons.map,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildQuickStatRow(
            'Completed Visits',
            '${journeyStats['completedVisits'] ?? 0}',
            Icons.check_circle,
            Colors.orange,
          ),
        ],
        const SizedBox(height: 8),
        GoldGradientButton(
          onPressed: _loadDetailedStats,
          child: const Text('View Detailed Stats'),
        ),
      ],
    );
  }

  Widget _buildQuickStatRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    final loginStats = _detailedStats!['login'] as Map<String, dynamic>? ?? {};
    final journeyStats = _detailedStats!['journey'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildStatCard(
          'Total Hours Worked',
          loginStats['formattedDuration'] ?? '0h 0m',
          Icons.access_time,
          Colors.blue,
          subtitle: '${loginStats['sessionCount'] ?? 0} sessions',
        ),
        const SizedBox(height: 8),
        _buildStatCard(
          'Journey Plans',
          '${journeyStats['totalPlans'] ?? 0}',
          Icons.map,
          Colors.green,
          subtitle: '${journeyStats['completedVisits'] ?? 0} completed',
        ),
        const SizedBox(height: 8),
        _buildStatCard(
          'Completion Rate',
          journeyStats['completionRate'] ?? '0%',
          Icons.analytics,
          Colors.orange,
          subtitle: '${journeyStats['completedVisits'] ?? 0} of ${journeyStats['totalPlans'] ?? 0}',
        ),
        if (journeyStats['clientVisits'] != null &&
            (journeyStats['clientVisits'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildClientVisitsCard(journeyStats['clientVisits'] as List<dynamic>),
        ],
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
    );
  }

  Widget _buildClientVisitsCard(List<dynamic> clientVisits) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          ...clientVisits.map((client) {
            final clientMap = client as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      clientMap['clientName'] ?? 'Unknown Client',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${clientMap['visitCount']} visits',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Details for ${DateFormat('MMMM d, yyyy').format(widget.day)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              GoldGradientButton(
                                onPressed: _loadDetailedStats,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _detailedStats != null
                          ? _buildDetailedStats()
                          : _buildQuickStats(),
            ),
          ),
        ],
      ),
    );
  }
} 