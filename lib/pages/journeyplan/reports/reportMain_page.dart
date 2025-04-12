import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/pages/journeyplan/reports/product_availability_page.dart';
import 'package:woosh/pages/journeyplan/reports/visibility_activity_page.dart';
import 'package:woosh/pages/journeyplan/reports/feedback_page.dart';
import 'package:woosh/utils/config.dart';

/// Main Reports Selection Page with card-based UI
class ReportsOrdersPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onAllReportsSubmitted;

  const ReportsOrdersPage({
    super.key,
    required this.journeyPlan,
    this.onAllReportsSubmitted,
  });

  @override
  State<ReportsOrdersPage> createState() => _ReportsOrdersPageState();
}

class _ReportsOrdersPageState extends State<ReportsOrdersPage> {
  bool _isLoading = false;
  List<Report> _submittedReports = [];
  bool _isCheckingOut = false;
  
  @override
  void initState() {
    super.initState();
    // No need to load reports on init as this page is for updating reports
  }

  // This page doesn't need to fetch reports as it's for updating reports only

  void _navigateToProductAvailability() {
    Get.to(
      () => ProductAvailabilityPage(
        journeyPlan: widget.journeyPlan,
      ),
    );
  }

  void _navigateToVisibilityActivity() {
    Get.to(
      () => VisibilityActivityPage(
        journeyPlan: widget.journeyPlan,
      ),
    );
  }

  void _navigateToFeedback() {
    Get.to(
      () => FeedbackPage(
        journeyPlan: widget.journeyPlan,
      ),
    );
  }

  Future<void> _confirmCheckout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Checkout'),
        content: const Text(
          'Are you sure you want to complete this visit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _checkOut();
    }
  }

  Future<void> _checkOut() async {
    if (_isCheckingOut) return;

    setState(() {
      _isCheckingOut = true;
    });

    try {
      // Update journey plan status to completed
      Map<String, dynamic> updateData = {
        'journeyId': widget.journeyPlan.id!,
        'outletId': widget.journeyPlan.outlet.id,
        'status': JourneyPlan.statusCompleted,
        'checkoutTime': DateTime.now().toIso8601String(),
      };
      
      // Make API call to update journey plan
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/journey-plans/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${GetStorage().read('token')}',
        },
        body: json.encode(updateData),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update journey plan');
      }
      
      if (widget.onAllReportsSubmitted != null) {
        widget.onAllReportsSubmitted!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error checking out: $e');
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete visit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // No refresh button needed as this page is for updating reports only
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outlet info card - more compact
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.store, size: 20, color: Color(0xFFC69C6D)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.journeyPlan.outlet.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.journeyPlan.outlet.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select Report Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildReportCard(
                          title: 'Product Availability',
                          icon: Icons.inventory,
                          color: Colors.blue,
                          onTap: _navigateToProductAvailability,
                          submittedCount: _submittedReports
                              .where((r) => r.type == ReportType.PRODUCT_AVAILABILITY)
                              .length,
                        ),
                        const SizedBox(height: 8),
                        _buildReportCard(
                          title: 'Visibility Activity',
                          icon: Icons.visibility,
                          color: Colors.orange,
                          onTap: _navigateToVisibilityActivity,
                          submittedCount: _submittedReports
                              .where((r) => r.type == ReportType.VISIBILITY_ACTIVITY)
                              .length,
                        ),
                        const SizedBox(height: 8),
                        _buildReportCard(
                          title: 'Feedback',
                          icon: Icons.feedback,
                          color: Colors.green,
                          onTap: _navigateToFeedback,
                          submittedCount: _submittedReports
                              .where((r) => r.type == ReportType.FEEDBACK)
                              .length,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCheckingOut ? null : _confirmCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC69C6D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: _isCheckingOut
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Complete Visit'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int submittedCount,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: submittedCount > 0 ? Colors.green : Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        submittedCount > 0 ? '$submittedCount Submitted' : 'Not Submitted',
                        style: TextStyle(
                          fontSize: 10,
                          color: submittedCount > 0 ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}