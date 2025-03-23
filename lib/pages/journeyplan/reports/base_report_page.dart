import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/report/report_model.dart';
import 'package:whoosh/services/api_service.dart';

mixin BaseReportPageMixin<T extends StatefulWidget> on State<T> {
  TextEditingController get commentController => _commentController;
  bool get isSubmitting => _isSubmitting;
  set isSubmitting(bool value) => _isSubmitting = value;

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  final _apiService = ApiService();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void resetForm() {
    setState(() {
      _commentController.clear();
      _isSubmitting = false;
    });
  }

  Future<void> submitReport(Report report) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await _apiService.submitReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
        resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget buildOutletInfo() {
    final journeyPlan = (widget as BaseReportPage).journeyPlan;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              journeyPlan.outlet.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Address: ${journeyPlan.outlet.address}'),
            if (journeyPlan.outlet.latitude != null &&
                journeyPlan.outlet.longitude != null)
              Text(
                  'Location: ${journeyPlan.outlet.latitude}, ${journeyPlan.outlet.longitude}'),
          ],
        ),
      ),
    );
  }

  Widget buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () => onSubmit(),
        child: _isSubmitting
            ? const CircularProgressIndicator()
            : const Text('Submit Report'),
      ),
    );
  }

  Future<void> onSubmit() async {
    // To be implemented by subclasses
  }

  Widget buildReportForm() {
    return const SizedBox.shrink(); // To be implemented by subclasses
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${(widget as BaseReportPage).reportType.name} Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildOutletInfo(),
            const SizedBox(height: 16),
            buildReportForm(),
            const SizedBox(height: 16),
            buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}

class BaseReportPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final ReportType reportType;

  const BaseReportPage({
    super.key,
    required this.journeyPlan,
    required this.reportType,
  });

  @override
  State<BaseReportPage> createState() => _BaseReportPageState();
}

class _BaseReportPageState extends State<BaseReportPage>
    with BaseReportPageMixin {
  @override
  Widget build(BuildContext context) => super.build(context);

  @override
  Future<void> onSubmit() async {
    // Base implementation does nothing
  }
}
