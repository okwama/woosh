import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/feedbackReport_model.dart';
import 'package:woosh/pages/journeyplan/reports/base_report_page.dart';

class FeedbackReportPage extends BaseReportPage {
  const FeedbackReportPage({super.key, required super.journeyPlan})
      : super(
          reportType: ReportType.FEEDBACK,
        );

  @override
  State<FeedbackReportPage> createState() => _FeedbackReportPageState();
}

class _FeedbackReportPageState extends State<FeedbackReportPage>
    with BaseReportPageMixin {
  @override
  void initState() {
    super.initState();
    print('DRASTIC DEBUG: FEEDBACK REPORT PAGE INITIALIZED');
    print('Journey Plan Details:');
    print('Journey Plan ID: ${widget.journeyPlan.id}');
    print(
        'Journey Plan User ID: ${widget.journeyPlan.userId} (${widget.journeyPlan.userId.runtimeType})');
    print('Journey Plan Outlet ID: ${widget.journeyPlan.outletId}');

    // Try to get user ID from storage for comparison
    final box = GetStorage();
    final userData = box.read('user');
    if (userData != null) {
      print('User data from storage: $userData');
      print(
          'User ID from storage: ${userData['id']} (${userData['id'].runtimeType})');

      // Compare user IDs
      final storedUserId = userData['id'];
      final journeyUserId = widget.journeyPlan.userId;
      print('User ID comparison:');
      print('Direct equality: ${storedUserId == journeyUserId}');
      print(
          'String equality: ${storedUserId.toString() == journeyUserId.toString()}');
    } else {
      print('WARNING: No user data found in storage');
    }
  }

  @override
  Future<void> onSubmit() async {
    print('DRASTIC DEBUG: FEEDBACK REPORT SUBMISSION STARTED');

    if (commentController.text.trim().isEmpty) {
      print('DRASTIC DEBUG: Empty comment detected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter feedback')),
      );
      return;
    }

    if (widget.journeyPlan.userId == null) {
      print('DRASTIC DEBUG: NULL USER ID IN JOURNEY PLAN');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found in journey plan')),
      );
      return;
    }

    // Get user ID from storage
    final box = GetStorage();
    final userData = box.read('user');
    int? userIdToUse = widget.journeyPlan.userId;

    // EMERGENCY FIX: Try to use the ID from storage if there's a mismatch
    if (userData != null) {
      final storedUserId = userData['id'];
      print(
          'DRASTIC DEBUG: User ID from storage: $storedUserId (${storedUserId.runtimeType})');
      print(
          'DRASTIC DEBUG: User ID from journey: $userIdToUse (${userIdToUse.runtimeType})');

      // If they don't match, try to use the stored ID
      if (storedUserId.toString() != userIdToUse.toString()) {
        print('DRASTIC DEBUG: USER ID MISMATCH - Using ID from storage');
        // Try to convert to int if possible
        if (storedUserId is int) {
          userIdToUse = storedUserId;
        } else if (storedUserId is String) {
          userIdToUse = int.tryParse(storedUserId) ?? userIdToUse;
        } else {
          userIdToUse = int.tryParse(storedUserId.toString()) ?? userIdToUse;
        }
        print(
            'DRASTIC DEBUG: Using converted user ID: $userIdToUse (${userIdToUse.runtimeType})');
      }
    }

    print('DRASTIC DEBUG: Creating report with:');
    print('Type: ${ReportType.FEEDBACK}');
    print('Journey Plan ID: ${widget.journeyPlan.id}');
    print('User ID: $userIdToUse');
    print('Outlet ID: ${widget.journeyPlan.outletId}');
    print('Comment: ${commentController.text}');

    final report = Report(
      type: ReportType.FEEDBACK,
      journeyPlanId: widget.journeyPlan.id!,
      userId: userIdToUse!,
      outletId: widget.journeyPlan.outletId,
      feedbackReport: FeedbackReport(
        reportId: 0,
        comment: commentController.text,
      ),
    );

    print('DRASTIC DEBUG: Report created, submitting...');
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
            Text(
              'Outlet: ${widget.journeyPlan.outlet.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Address: ${widget.journeyPlan.outlet.address}',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 5,
              decoration: const InputDecoration(
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
