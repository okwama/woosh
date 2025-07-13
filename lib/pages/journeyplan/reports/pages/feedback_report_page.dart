import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/feedbackReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class FeedbackReportPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onReportSubmitted;

  const FeedbackReportPage({
    super.key,
    required this.journeyPlan,
    this.onReportSubmitted,
  });

  @override
  State<FeedbackReportPage> createState() => _FeedbackReportPageState();
}

class _FeedbackReportPageState extends State<FeedbackReportPage> {
  final _commentController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  bool _hasUnsyncedChanges = false;

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Optimistically show success and navigate back
      widget.onReportSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      final box = GetStorage();
      final salesRepData = box.read('salesRep');
      final int? salesRepId =
          salesRepData is Map<String, dynamic> ? salesRepData['id'] : null;

      if (salesRepId == null) {
        throw Exception(
            "User not authenticated: Could not determine salesRep ID");
      }

      Report report = Report(
        type: ReportType.FEEDBACK,
        journeyPlanId: widget.journeyPlan.id,
        salesRepId: salesRepId,
        clientId: widget.journeyPlan.client.id,
        feedbackReport: FeedbackReport(
          reportId: 0,
          comment: _commentController.text,
        ),
      );

      // Submit in background
      await _apiService.submitReport(report);
    } catch (e) {
      // If background submission fails, show error but don't disrupt flow
      if (mounted) {
        String errorMessage = 'Unable to sync your feedback';
        if (e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('connection')) {
          errorMessage =
              'No internet connection. Your feedback will sync when online.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitReport,
            ),
          ),
        );
        setState(() => _hasUnsyncedChanges = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsyncedChanges) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsynced changes. Discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldDiscard ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: appBackground,
        appBar: GradientAppBar(
          title: 'Feedback Report',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Outlet Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.journeyPlan.client.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.journeyPlan.client.address,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Feedback Report Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _commentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Feedback',
                          hintText: 'Enter your feedback here...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Submitting...'),
                                  ],
                                )
                              : const Text('Submit Report'),
                        ),
                      ),
                      if (_hasUnsyncedChanges) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Changes not synced. Tap submit to retry.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
