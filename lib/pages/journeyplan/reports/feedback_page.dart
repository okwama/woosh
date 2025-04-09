import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/feedbackReport_model.dart';
import 'package:woosh/pages/journeyplan/reports/base_report_page.dart';

class FeedbackPage extends BaseReportPage {
  const FeedbackPage({
    super.key,
    required super.journeyPlan,
  }) : super(reportType: ReportType.FEEDBACK);

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with BaseReportPageMixin {
  @override
  Future<void> onSubmit() async {
    if (commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    final box = GetStorage();
    final userId = box.read('userId');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final report = Report(
      type: ReportType.FEEDBACK,
      journeyPlanId: widget.journeyPlan.id!,
      userId: userId,
      outletId: widget.journeyPlan.outletId,
      feedbackReport: FeedbackReport(
        reportId: 0, // This will be set by the backend
        comment: commentController.text,
      ),
    );

    await submitReport(report);
  }

  @override
  Widget buildReportForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Your Feedback',
                hintText: 'Enter your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
