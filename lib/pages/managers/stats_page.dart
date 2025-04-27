import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:woosh/services/api_service.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:woosh/utils/app_theme.dart' hide CreamGradientCard;
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/cream_gradient_card.dart';

class ManagerStatsPage extends StatefulWidget {
  const ManagerStatsPage({super.key});

  @override
  State<ManagerStatsPage> createState() => _ManagerStatsPageState();
}

class _ManagerStatsPageState extends State<ManagerStatsPage> {
  String _selectedPeriod = 'week';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
        Uri.parse(
            '${ApiService.baseUrl}/checkin/working-hours?period=$_selectedPeriod'),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Work Statistics',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: GradientCircularProgressIndicator());
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 8),
            _buildStatsCards(),
          ],
        ),
      ),
    );
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
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
          setState(() => _selectedPeriod = value);
          _loadStats();
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildStatCard(
          'Working Hours',
          _stats!['formattedDuration'] ?? '0h 0m',
          Icons.access_time,
          Colors.blue,
        ),
        const SizedBox(height: 6),
        _buildStatCard(
          'Completed Visits',
          '${_stats!['completedVisits'] ?? 0}',
          Icons.place,
          Colors.green,
        ),
        const SizedBox(height: 6),
        _buildStatCard(
          'Average Visit Duration',
          _calculateAverageVisitDuration(),
          Icons.timer,
          Colors.orange,
        ),
      ],
    );
  }

  String _calculateAverageVisitDuration() {
    if (_stats == null || _stats!['completedVisits'] == 0) return '0h 0m';

    final totalHours = _stats!['totalHours'] ?? 0;
    final totalMinutes = _stats!['totalMinutes'] ?? 0;
    final visits = _stats!['completedVisits'] ?? 1;

    final totalMinutesAvg = ((totalHours * 60) + totalMinutes) ~/ visits;
    final hours = totalMinutesAvg ~/ 60;
    final minutes = totalMinutesAvg % 60;

    return '${hours}h ${minutes}m';
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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
}
