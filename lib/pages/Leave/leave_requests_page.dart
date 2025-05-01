import 'package:flutter/material.dart';
import 'package:woosh/models/leave_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({super.key});

  @override
  _LeaveRequestsPageState createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  List<Leave> _leaves = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    try {
      final leaves = await ApiService.getUserLeaves();
      setState(() {
        _leaves = leaves;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leave requests: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.PENDING:
        return Colors.orange;
      case LeaveStatus.APPROVED:
        return Colors.green;
      case LeaveStatus.DECLINED:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Leave Requests',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLeaves,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _leaves.isEmpty
                  ? const Center(
                      child: Text('No leave requests found'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaves,
                      child: ListView.builder(
                        key: const PageStorageKey('leave_requests_list'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _leaves.length,
                        itemBuilder: (context, index) {
                          final leave = _leaves[index];
                          return Card(
                            key: ValueKey('leave_${leave.id}_$index'),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        leave.leaveType,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: goldGradient,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          leave.status
                                              .toString()
                                              .split('.')
                                              .last,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'From: ${DateFormat('MMM dd, yyyy').format(leave.startDate)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        'To: ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (leave.attachment != null) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.attach_file, size: 16),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Attachment: ${leave.attachment!.split('/').last.length > 8 ? leave.attachment!.split('/').last.substring(0, 8) + '...' : leave.attachment!.split('/').last}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    'Reason: ${leave.reason}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
