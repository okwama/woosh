import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/models/report/report_model.dart';
import 'package:glamour_queen/pages/managers/teamRepor/SalesRepReportDetailPage.dart';
import 'package:glamour_queen/pages/managers/service/salesRepReport_service.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/gradient_widgets.dart';

class SalesRepReportsPage extends StatefulWidget {
  const SalesRepReportsPage({super.key});

  @override
  State<SalesRepReportsPage> createState() => _SalesRepReportsPageState();
}

class _SalesRepReportsPageState extends State<SalesRepReportsPage> {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Report> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      print('\n=== DEBUG: Starting to load reports ===');
      setState(() => _isLoading = true);
      
      final reportService = SalesRepReportService();
      
      // First, get the sales reps
      print('\n=== DEBUG: Fetching sales reps ===');
      final salesReps = await reportService.getSalesRepsByManagerRoute();
      print('DEBUG: Fetched ${salesReps.length} sales reps');
      for (var rep in salesReps) {
        print('DEBUG: Sales Rep - ID: ${rep.id}, Name: ${rep.name}, Route: ${rep.route}');
      }
      
      if (salesReps.isEmpty) {
        print('DEBUG: No sales reps found');
        setState(() {
          _isLoading = false;
          _reports = [];
        });
        return;
      }

      // Get reports for the first sales rep immediately
      try {
        final firstSalesRep = salesReps.first;
        print('\n=== DEBUG: Fetching initial reports for first sales rep ===');
        print('DEBUG: First Sales Rep - ID: ${firstSalesRep.id}, Name: ${firstSalesRep.name}');
        
        List<Report> initialReports = [];
        try {
          initialReports = await reportService.getSalesRepReports(
            salesRepId: firstSalesRep.id,
          );
          print('DEBUG: Fetched ${initialReports.length} initial reports');
          for (var report in initialReports) {
            print('DEBUG: Initial Report - ID: ${report.id}, Type: ${report.type}, Date: ${report.createdAt}, User: ${report.user?.name}');
          }
        } catch (e) {
          print('ERROR: Failed to load initial reports: $e');
          initialReports = []; // Use empty list on error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading some reports: ${e.toString()}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        // Display the first batch of reports immediately
        setState(() {
          _reports = initialReports;
          _isLoading = false;
        });
        print('DEBUG: Updated UI with initial reports');

        // Then load the rest in the background
        if (salesReps.length > 1) {
          print('\n=== DEBUG: Starting background loading for remaining sales reps ===');
          setState(() => _isLoadingMore = true);
          
          final remainingReports = <Report>[];
          for (final salesRep in salesReps.skip(1)) {
            try {
              print('\nDEBUG: Fetching reports for sales rep - ID: ${salesRep.id}, Name: ${salesRep.name}');
              List<Report> reports = [];
              try {
                reports = await reportService.getSalesRepReports(
                  salesRepId: salesRep.id,
                );
                print('DEBUG: Fetched ${reports.length} reports for sales rep ${salesRep.id}');
                for (var report in reports) {
                  print('DEBUG: Report - ID: ${report.id}, Type: ${report.type}, Date: ${report.createdAt}, User: ${report.user?.name}');
                }
              } catch (e) {
                print('ERROR: Failed to load reports for sales rep ${salesRep.id}: $e');
                reports = []; // Use empty list on error
              }
              
              remainingReports.addAll(reports);
              
              // Update the UI with new reports as they come in
              setState(() {
                _reports = [..._reports, ...reports];
              });
              print('DEBUG: Updated UI with new reports, total reports now: ${_reports.length}');
            } catch (e) {
              print('ERROR: Failed to load reports for sales rep ${salesRep.id}: $e');
            }
          }
          
          setState(() => _isLoadingMore = false);
          print('\n=== DEBUG: Background loading completed ===');
          print('DEBUG: Total reports loaded: ${_reports.length}');
        }
      } catch (e) {
        print('ERROR: Failed to load initial reports: $e');
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading reports: ${e.toString()}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: Failed to load sales reps: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales reps: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _getSafeDisplayName(Report report) {
    try {
      if (report.user?.name != null && report.user!.name.isNotEmpty) {
        return report.user!.name;
      }
      return 'Sales Rep #${report.salesRepId}';
        } catch (e) {
      print('Error getting display name: $e');
    }
    return 'Unknown User';
  }

  String _getSafeReportType(Report report) {
    try {
      final typeStr = report.type.toString().split('.').last;
      return typeStr.replaceAll('_', ' ');
        } catch (e) {
      print('Error getting report type: $e');
    }
    return 'Unknown Type';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Sales Rep Reports',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingMore)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const LinearProgressIndicator(),
            ),
          Expanded(
            child: _isLoading
              ? const Center(child: GradientCircularProgressIndicator())
              : _reports.isEmpty
                ? const Center(child: Text('No reports found'))
                : ListView.builder(
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(_getSafeDisplayName(report)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${_getSafeReportType(report)}'),
                              Text('Date: ${report.createdAt?.toString() ?? 'Unknown'}'),
                            ],
                          ),
                          onTap: () {
                            if (report.user != null) {
                              Get.to(() => SalesRepReportDetailPage(
                                salesRep: report.user!,
                              ));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot view details: User information not available'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

