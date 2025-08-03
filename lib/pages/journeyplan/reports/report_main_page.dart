import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/services/journeyplan/jouneyplan_service.dart';
import 'package:woosh/models/report/product_report_model.dart';
import 'package:woosh/models/report/feedback_report_model.dart';
import 'package:woosh/models/report/visibility_report_model.dart';
import 'package:woosh/models/report/product_return_model.dart';
import 'package:woosh/pages/journeyplan/reports/pages/feedback_report_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_report_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_sample.dart';
import 'package:woosh/pages/journeyplan/reports/pages/visibility_report_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_return_page.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/report/report_service.dart';
import 'package:woosh/services/shared_data_service.dart';
import 'package:woosh/services/journeyplan/journey_plan_state_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

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
  final _commentController = TextEditingController();
  final _quantityController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  bool _isLoading = true;
  Product? _selectedProduct;
  File? _imageFile;
  String? _imageUrl;
  final ReportType _selectedReportType = ReportType.PRODUCT_AVAILABILITY;
  List<Product> _products = [];
  List<Report> _submittedReports = [];
  bool _isCheckingOut = false;
  bool _isUsingCache = false;
  late final SharedDataService _sharedDataService;

  @override
  void initState() {
    super.initState();
    _sharedDataService = Get.find<SharedDataService>();
    _loadProducts();
    _loadExistingReports();
  }

  Future<void> _loadProducts() async {
    try {
      // Use shared data service instead of direct API call
      final products = _sharedDataService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _loadExistingReports() async {
    try {
      // Use shared data service to get reports
      final reports =
          _sharedDataService.getReportsForJourneyPlan(widget.journeyPlan.id!);

      // Filter for today's reports only
      final today = DateTime.now();
      final todayReports = reports.where((report) {
        if (report.createdAt == null) return false;
        final reportDate = report.createdAt!;
        return reportDate.year == today.year &&
            reportDate.month == today.month &&
            reportDate.day == today.day;
      }).toList();

      setState(() {
        _submittedReports = todayReports;
        _isUsingCache = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadExistingReports();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reports refreshed')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final imageUrl = await ApiService.uploadImage(_imageFile!);
      setState(() => _imageUrl = imageUrl);
      return imageUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    // Validate form first
    if (_selectedReportType == ReportType.PRODUCT_AVAILABILITY &&
        _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    if (_selectedReportType == ReportType.VISIBILITY_ACTIVITY &&
        _imageFile == null &&
        _imageUrl == null &&
        _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image or comment')),
      );
      return;
    }

    if (_selectedReportType == ReportType.FEEDBACK &&
        _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl = await _uploadImage();

      // Get the currently logged in salesRep from storage
      final box = GetStorage();
      final salesRepData = box.read('salesRep');

      if (salesRepData == null) {
        throw Exception("User not authenticated: No salesRep data found");
      }

      // Extract the salesRep ID from the stored data
      final int? salesRepId =
          salesRepData is Map<String, dynamic> ? salesRepData['id'] : null;

      if (salesRepId == null) {
        throw Exception(
            "User not authenticated: Could not determine salesRep ID");
      }

      print(
          'Creating report using salesRepId: $salesRepId from stored salesRep data');

      Report report;
      switch (_selectedReportType) {
        case ReportType.PRODUCT_AVAILABILITY:
          report = Report(
            type: ReportType.PRODUCT_AVAILABILITY,
            journeyPlanId: widget.journeyPlan.id,
            salesRepId: salesRepId,
            clientId: widget.journeyPlan.client.id,
            productReport: ProductReport(
              reportId: 0,
              productName: _selectedProduct?.productName,
              quantity: int.tryParse(_quantityController.text),
              comment: _commentController.text,
            ),
          );
          break;
        case ReportType.VISIBILITY_ACTIVITY:
          report = Report(
            type: ReportType.VISIBILITY_ACTIVITY,
            journeyPlanId: widget.journeyPlan.id,
            salesRepId: salesRepId,
            clientId: widget.journeyPlan.client.id,
            visibilityReport: VisibilityReport(
              reportId: 0,
              comment: _commentController.text,
              imageUrl: imageUrl,
            ),
          );
          break;
        case ReportType.FEEDBACK:
          report = Report(
            type: ReportType.FEEDBACK,
            journeyPlanId: widget.journeyPlan.id,
            salesRepId: salesRepId,
            clientId: widget.journeyPlan.client.id,
            feedbackReport: FeedbackReport(
              reportId: 0,
              comment: _commentController.text,
            ),
          );
          break;
        case ReportType.PRODUCT_RETURN:
          report = Report(
            type: ReportType.PRODUCT_RETURN,
            journeyPlanId: widget.journeyPlan.id,
            salesRepId: salesRepId,
            clientId: widget.journeyPlan.client.id,
            productReturn: ProductReturn(
              reportId: 0,
              productName: _selectedProduct?.productName,
              reason: _commentController.text,
              imageUrl: imageUrl,
              quantity: int.tryParse(_quantityController.text),
            ),
          );
          break;
        case ReportType.PRODUCT_SAMPLE:
          // TODO: Implement product sample report creation
          throw UnimplementedError('Product sample report not implemented yet');
      }

      // Debug: Validate report object before submission
      print(
          'REPORT SUBMISSION DEBUG: Report journeyPlanId: ${report.journeyPlanId}');

      switch (report.type) {
        case ReportType.PRODUCT_AVAILABILITY:
          if (report.productReport == null) {
            throw Exception('Product report details are missing');
          }
          print(
              'REPORT SUBMISSION DEBUG: ProductReport: ${report.productReport?.productName}, Quantity: ${report.productReport?.quantity}, Comment: ${report.productReport?.comment}');
          break;
        case ReportType.VISIBILITY_ACTIVITY:
          if (report.visibilityReport == null) {
            throw Exception('Visibility report details are missing');
          }
          print(
              'REPORT SUBMISSION DEBUG: VisibilityReport: Comment: ${report.visibilityReport?.comment}, ImageUrl: ${report.visibilityReport?.imageUrl}');
          break;
        case ReportType.FEEDBACK:
          if (report.feedbackReport == null) {
            throw Exception('Feedback report details are missing');
          }
          print(
              'REPORT SUBMISSION DEBUG: FeedbackReport: Comment: ${report.feedbackReport?.comment}');
          break;
        case ReportType.PRODUCT_RETURN:
          if (report.productReturn == null) {
            throw Exception('Product return details are missing');
          }
          print(
              'REPORT SUBMISSION DEBUG: ProductReturn: Product: ${report.productReturn?.productName}, Reason: ${report.productReturn?.reason}, Quantity: ${report.productReturn?.quantity}');
          break;
        case ReportType.PRODUCT_SAMPLE:
          // TODO: Implement product sample report debug/validation
          throw UnimplementedError(
              'Product sample report debug not implemented yet');
      }

      await ReportsService.submitReport(report);

      setState(() {
        _submittedReports.add(report);
        _resetForm();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      // Check if all required reports are submitted
      if (_areAllReportsSubmitted()) {
        widget.onAllReportsSubmitted?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _areAllReportsSubmitted() {
    bool hasProductReport =
        _submittedReports.any((r) => r.type == ReportType.PRODUCT_AVAILABILITY);
    bool hasVisibilityReport =
        _submittedReports.any((r) => r.type == ReportType.VISIBILITY_ACTIVITY);
    bool hasFeedbackReport =
        _submittedReports.any((r) => r.type == ReportType.FEEDBACK);

    // Product Sample is optional, so only require the 3 main reports
    return hasProductReport && hasVisibilityReport && hasFeedbackReport;
  }

  // Helper methods for visual indicators
  bool _isReportSubmitted(ReportType type) {
    return _submittedReports
        .any((r) => r.type == type && _isReportValidToday(r));
  }

  bool _isReportValidToday(Report report) {
    if (report.createdAt == null) return false;

    final now = DateTime.now();
    final reportDate = report.createdAt!;

    // Check if report was submitted today
    return reportDate.year == now.year &&
        reportDate.month == now.month &&
        reportDate.day == now.day;
  }

  Report? _getSubmittedReport(ReportType type) {
    try {
      return _submittedReports.firstWhere((r) => r.type == type);
    } catch (e) {
      return null;
    }
  }

  String _getReportTimestamp(ReportType type) {
    final report = _getSubmittedReport(type);
    if (report?.createdAt != null) {
      final now = DateTime.now();
      final submitted = report!.createdAt!;

      // Check if report is from today
      final isToday = submitted.year == now.year &&
          submitted.month == now.month &&
          submitted.day == now.day;

      if (!isToday) {
        // Report is from a previous day - show date
        return '${submitted.day}/${submitted.month} (Expired)';
      }

      // Report is from today - show relative time
      final difference = now.difference(submitted);
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    }
    return '';
  }

  Widget _buildReportButton({
    required String title,
    required IconData icon,
    required ReportType reportType,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    final isSubmitted = _isReportSubmitted(reportType);
    final timestamp = _getReportTimestamp(reportType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubmitted
                    ? Colors.green.shade100
                    : (backgroundColor ?? Theme.of(context).primaryColor),
                foregroundColor:
                    isSubmitted ? Colors.green.shade800 : Colors.white,
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size.fromHeight(48),
                side: isSubmitted
                    ? BorderSide(color: Colors.green.shade300, width: 2)
                    : null,
              ),
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  if (isSubmitted) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                  ],
                ],
              ),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSubmitted ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isSubmitted && timestamp.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isSubmitted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _resetForm() {
    _commentController.clear();
    _quantityController.clear();
    _selectedProduct = null;
    _imageFile = null;
    _imageUrl = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Reports & Sales',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outlet Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.journeyPlan.client.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.journeyPlan.client.address ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Progress Indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Visit Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isUsingCache)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cached,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Cached',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _areAllReportsSubmitted()
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_submittedReports.length}/3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _areAllReportsSubmitted()
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _submittedReports.length / 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _areAllReportsSubmitted()
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _areAllReportsSubmitted()
                          ? 'All required reports completed! Ready to check out.'
                          : 'Complete the remaining required reports to finish your visit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _areAllReportsSubmitted()
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Report Type Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // // Sales Button
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: ElevatedButton.icon(
                    //     onPressed: () {
                    //       Navigator.push(
                    //         context,
                    //         MaterialPageRoute(
                    //           builder: (context) => SalesPage(
                    //             journeyPlan: widget.journeyPlan,
                    //           ),
                    //         ),
                    //       );
                    //     },
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor: Theme.of(context).primaryColor,
                    //       foregroundColor: Colors.white,
                    //       alignment: Alignment.centerLeft,
                    //       padding: const EdgeInsets.symmetric(
                    //           vertical: 8, horizontal: 12),
                    //       minimumSize: const Size.fromHeight(36),
                    //     ),
                    //     icon: const Icon(Icons.shopping_cart, size: 18),
                    //     label: const Text('Post Sales',
                    //         style: TextStyle(fontSize: 13)),
                    //   ),
                    // ),
                    const SizedBox(height: 6),
                    // Product Availability Button
                    _buildReportButton(
                      title: 'Product Availability',
                      icon: Icons.inventory,
                      reportType: ReportType.PRODUCT_AVAILABILITY,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductReportPage(
                              journeyPlan: widget.journeyPlan,
                              onReportSubmitted: () async {
                                final newReport = Report(
                                  type: ReportType.PRODUCT_AVAILABILITY,
                                  journeyPlanId: widget.journeyPlan.id,
                                  salesRepId:
                                      GetStorage().read('salesRep')['id'],
                                  clientId: widget.journeyPlan.client.id,
                                  createdAt: DateTime.now(),
                                );

                                setState(() {
                                  _submittedReports.add(newReport);
                                });

                                // Cache the updated reports
                                await _sharedDataService
                                    .cacheReports(_submittedReports);

                                if (_areAllReportsSubmitted()) {
                                  widget.onAllReportsSubmitted?.call();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    // Visibility Activity Button
                    _buildReportButton(
                      title: 'Visibility Activity',
                      icon: Icons.photo_camera,
                      reportType: ReportType.VISIBILITY_ACTIVITY,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VisibilityReportPage(
                              journeyPlan: widget.journeyPlan,
                              onReportSubmitted: () async {
                                final newReport = Report(
                                  type: ReportType.VISIBILITY_ACTIVITY,
                                  journeyPlanId: widget.journeyPlan.id,
                                  salesRepId:
                                      GetStorage().read('salesRep')['id'],
                                  clientId: widget.journeyPlan.client.id,
                                  createdAt: DateTime.now(),
                                );

                                setState(() {
                                  _submittedReports.add(newReport);
                                });

                                // Cache the updated reports
                                await _sharedDataService
                                    .cacheReports(_submittedReports);

                                if (_areAllReportsSubmitted()) {
                                  widget.onAllReportsSubmitted?.call();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    // Feedback Button
                    _buildReportButton(
                      title: 'Feedback',
                      icon: Icons.feedback,
                      reportType: ReportType.FEEDBACK,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeedbackReportPage(
                              journeyPlan: widget.journeyPlan,
                              onReportSubmitted: () async {
                                final newReport = Report(
                                  type: ReportType.FEEDBACK,
                                  journeyPlanId: widget.journeyPlan.id,
                                  salesRepId:
                                      GetStorage().read('salesRep')['id'],
                                  clientId: widget.journeyPlan.client.id,
                                  createdAt: DateTime.now(),
                                );

                                setState(() {
                                  _submittedReports.add(newReport);
                                });

                                // Cache the updated reports
                                await _sharedDataService
                                    .cacheReports(_submittedReports);

                                if (_areAllReportsSubmitted()) {
                                  widget.onAllReportsSubmitted?.call();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    // Product Sample Button (Optional)
                    _buildReportButton(
                      title: 'Product Sample (Optional)',
                      icon: Icons.assignment_return,
                      reportType: ReportType.PRODUCT_SAMPLE,
                      backgroundColor: const Color.fromARGB(255, 145, 238, 122),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductSamplePage(
                              journeyPlan: widget.journeyPlan,
                              onReportSubmitted: () async {
                                final newReport = Report(
                                  type: ReportType.PRODUCT_SAMPLE,
                                  journeyPlanId: widget.journeyPlan.id,
                                  salesRepId:
                                      GetStorage().read('salesRep')['id'],
                                  clientId: widget.journeyPlan.client.id,
                                  createdAt: DateTime.now(),
                                );

                                setState(() {
                                  _submittedReports.add(newReport);
                                });

                                // Cache the updated reports
                                await _sharedDataService
                                    .cacheReports(_submittedReports);

                                if (_areAllReportsSubmitted()) {
                                  widget.onAllReportsSubmitted?.call();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Checkout Button
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Complete Visit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_areAllReportsSubmitted())
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ready',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _areAllReportsSubmitted()
                          ? 'All required reports completed! You can now check out to finish your visit.'
                          : 'Complete all required reports before checking out.',
                      style: TextStyle(
                        color: _areAllReportsSubmitted()
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isCheckingOut || !_areAllReportsSubmitted())
                                ? null
                                : _confirmCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _areAllReportsSubmitted()
                              ? Colors.green
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: _isCheckingOut
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                _areAllReportsSubmitted()
                                    ? Icons.check_circle
                                    : Icons.lock,
                                size: 18,
                              ),
                        label: _isCheckingOut
                            ? const Text('Processing...',
                                style: TextStyle(fontSize: 13))
                            : Text(
                                _areAllReportsSubmitted()
                                    ? 'CHECK OUT'
                                    : 'COMPLETE REPORTS FIRST',
                                style: const TextStyle(fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCheckout() async {
    if (_isCheckingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Checkout'),
        content: const Text(
          'Are you sure you want to check out from this location? This will mark your visit as complete.',
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
            child: const Text('CHECK OUT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processCheckout();
    }
  }

  Future<void> _processCheckout() async {
    setState(() {
      _isCheckingOut = true;
    });

    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
          'CHECKOUT: Position obtained: ${position.latitude}, ${position.longitude}');

      // Update journey plan with checkout information
      final response = await JourneyPlanService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusCompleted,
        checkoutTime: DateTime.now(),
        checkoutLatitude: position.latitude,
        checkoutLongitude: position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checkout completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear all caches after successful checkout
        await _sharedDataService.clearAllCaches();

        // Refresh journey plan status in state service
        try {
          final journeyPlanStateService = Get.find<JourneyPlanStateService>();
          await journeyPlanStateService
              .refreshJourneyPlanStatus(widget.journeyPlan.id!);
          print('✅ Journey plan status refreshed after checkout');
        } catch (e) {
          print('⚠️ Failed to refresh journey plan status: $e');
        }

        // Call the callback if provided
        widget.onAllReportsSubmitted?.call();

        // Navigate back after successful checkout
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }
}
