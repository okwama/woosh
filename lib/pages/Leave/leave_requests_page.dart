import 'package:flutter/material.dart';
import 'package:woosh/models/leave_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:intl/intl.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({Key? key}) : super(key: key);

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
      case LeaveStatus.REJECTED:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _leaves.length,
                        itemBuilder: (context, index) {
                          final leave = _leaves[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(leave.status)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          leave.status
                                              .toString()
                                              .split('.')
                                              .last,
                                          style: TextStyle(
                                            color:
                                                _getStatusColor(leave.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'From: ${DateFormat('MMM dd, yyyy').format(leave.startDate)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    'To: ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reason: ${leave.reason}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (leave.attachment != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.attach_file),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Attachment: ${leave.attachment!.split('/').last.length > 8 ? leave.attachment!.split('/').last.substring(0, 8) + '...' : leave.attachment!.split('/').last}',
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
