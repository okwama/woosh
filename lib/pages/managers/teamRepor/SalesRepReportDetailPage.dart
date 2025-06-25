import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:glamour_queen/models/user_model.dart';
import 'package:glamour_queen/models/report/report_model.dart';
import 'package:glamour_queen/pages/managers/service/salesRepReport_service.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';

class SalesRepReportDetailPage extends StatefulWidget {
  final SalesRep salesRep;
  
  const SalesRepReportDetailPage({
    super.key,
    required this.salesRep,
  });

  @override
  State<SalesRepReportDetailPage> createState() => _SalesRepReportDetailPageState();
}

class _SalesRepReportDetailPageState extends State<SalesRepReportDetailPage> {
  final _reportService = SalesRepReportService();
  DateTime? _startDate;
  DateTime? _endDate;
  ReportType? _selectedType;
  Map<int, List<Report>> _reportsByClient = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);
      
      final reports = await _reportService.getReportsGroupedByClient(
        salesRepId: widget.salesRep.id,
        type: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _reportsByClient = reports;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '${widget.salesRep.name}\'s Reports',
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Date Range Picker
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null 
                      ? 'Start Date' 
                      : DateFormat('MMM dd, yyyy').format(_startDate!)),
                    onPressed: () => _selectDate(true),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_endDate == null 
                      ? 'End Date' 
                      : DateFormat('MMM dd, yyyy').format(_endDate!)),
                    onPressed: () => _selectDate(false),
                  ),
                ),
              ],
            ),
            // Report Type Dropdown
            DropdownButton<ReportType>(
              value: _selectedType,
              hint: const Text('All Report Types'),
              isExpanded: true,
              items: ReportType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (type) {
                setState(() {
                  _selectedType = type;
                  _loadReports();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_reportsByClient.isEmpty) {
      return const Center(child: Text('No reports found'));
    }

    return ListView.builder(
      itemCount: _reportsByClient.length,
      itemBuilder: (context, index) {
        final clientId = _reportsByClient.keys.elementAt(index);
        final clientReports = _reportsByClient[clientId]!;
        final clientName = clientReports.first.client?.name ?? 'Unknown Client';

        return ExpansionTile(
          title: Text(clientName),
          subtitle: Text('${clientReports.length} reports'),
          children: clientReports.map((report) {
            return ListTile(
              title: Text(report.type.toString().split('.').last),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${DateFormat('MMM dd, yyyy').format(report.createdAt!)}'),
                  if (report.comment.isNotEmpty)
                    Text('Comment: ${report.comment}'),
                ],
              ),
              onTap: () {
                // Navigate to detailed report view if needed
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _loadReports();
      });
    }
  }
}

