// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/target_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/targets/add_edit_target_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Target> _targets = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortOption = 'endDate'; // Default sort by end date

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTargets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final targets = await ApiService.getTargets();
      setState(() {
        _targets = targets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load targets: $e';
        _isLoading = false;
      });
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
        targets.sort(
            (a, b) => b.completionPercentage.compareTo(a.completionPercentage));
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
    int totalCurrentValue = 0;

    for (var target in _targets) {
      totalTargetValue += target.targetValue;
      totalCurrentValue += target.currentValue;
    }

    return totalTargetValue > 0
        ? (totalCurrentValue / totalTargetValue) * 100
        : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Targets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTargets,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active (${_activeCount})'),
            Tab(text: 'Upcoming (${_upcomingCount})'),
            Tab(text: 'Completed (${_completedCount})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                      ElevatedButton(
                        onPressed: _loadTargets,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTargetPage(),
            ),
          );

          if (result == true) {
            _loadTargets();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 45.0,
              lineWidth: 10.0,
              percent: _overallProgress / 100,
              center: Text(
                "${_overallProgress.toStringAsFixed(0)}%",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
              progressColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey[300]!,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 1500,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
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
      onRefresh: _loadTargets,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: targets.length,
          itemBuilder: (context, index) {
            final target = targets[index];
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

  Widget _buildTargetCard(Target target) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final progress = target.completionPercentage;
    final daysLeft = target.endDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2,
      child: InkWell(
        onTap: () => _openTargetDetails(target),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: target.statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      target.typeText,
                      style: TextStyle(
                        color: target.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (target.description.isNotEmpty) ...[
                Text(
                  target.description,
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormatter.format(target.startDate)} - ${dateFormatter.format(target.endDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  if (!target.isCompleted &&
                      !target.isOverdue() &&
                      daysLeft >= 0) ...[
                    Icon(Icons.timer, size: 14, color: Colors.blue[400]),
                    const SizedBox(width: 4),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(
                          color: Colors.blue[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircularPercentIndicator(
                    radius: 25.0,
                    lineWidth: 5.0,
                    percent: progress / 100,
                    center: Text(
                      "${progress.toStringAsFixed(0)}%",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 10.0),
                    ),
                    progressColor: target.statusColor,
                    backgroundColor: Colors.grey[300]!,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress: ${target.currentValue} / ${target.targetValue}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(target.statusColor),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (target.isOverdue() && !target.isCompleted) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue by ${DateTime.now().difference(target.endDate).inDays} days',
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              if (!target.isCompleted) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.update),
                      onPressed: () => _updateProgress(target),
                      label: const Text('Update Progress'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openTargetDetails(Target target) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTargetPage(target: target),
      ),
    );

    if (result == true) {
      _loadTargets();
    }
  }

  void _updateProgress(Target target) async {
    final TextEditingController progressController = TextEditingController(
      text: target.currentValue.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Target: ${target.title}'),
            const SizedBox(height: 16),
            TextField(
              controller: progressController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Progress',
                hintText: 'Enter current value (max: ${target.targetValue})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(progressController.text) ?? 0;
              Navigator.pop(context, value);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateTargetProgress(target.id!, result);
        _loadTargets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progress updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update progress: $e')),
          );
        }
      }
    }
  }
}
