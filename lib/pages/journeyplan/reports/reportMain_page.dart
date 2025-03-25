import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/report/report_model.dart';
import 'package:whoosh/models/report/productReport_model.dart';
import 'package:whoosh/models/report/visibilityReport_model.dart';
import 'package:whoosh/models/report/feedbackReport_model.dart';
import 'package:whoosh/services/api_service.dart';

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
  ReportType _selectedReportType = ReportType.PRODUCT_AVAILABILITY;
  List<Product> _products = [];
  List<Report> _submittedReports = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ApiService.getProducts();
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

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload products
      await _loadProducts();

      // Load any existing reports for this journey
      try {
        final reports = await _apiService.getReports(
          journeyPlanId: widget.journeyPlan.id,
        );
        setState(() {
          _submittedReports = reports;
        });
      } catch (e) {
        print('Error loading existing reports: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reports refreshed')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl = await _uploadImage();

      Report report;
      switch (_selectedReportType) {
        case ReportType.PRODUCT_AVAILABILITY:
          report = Report(
            type: ReportType.PRODUCT_AVAILABILITY,
            journeyPlanId: widget.journeyPlan.id,
            userId: widget.journeyPlan.userId!,
            outletId: widget.journeyPlan.outlet.id,
            productReport: ProductReport(
              reportId: 0,
              productName: _selectedProduct?.name,
              quantity: int.tryParse(_quantityController.text),
              comment: _commentController.text,
            ),
          );
          break;
        case ReportType.VISIBILITY_ACTIVITY:
          report = Report(
            type: ReportType.VISIBILITY_ACTIVITY,
            journeyPlanId: widget.journeyPlan.id,
            userId: widget.journeyPlan.userId!,
            outletId: widget.journeyPlan.outlet.id,
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
            userId: widget.journeyPlan.userId!,
            outletId: widget.journeyPlan.outlet.id,
            feedbackReport: FeedbackReport(
              reportId: 0,
              comment: _commentController.text,
            ),
          );
          break;
      }

      await _apiService.submitReport(report);

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
    // Check if at least one report of each type has been submitted
    bool hasProductReport =
        _submittedReports.any((r) => r.type == ReportType.PRODUCT_AVAILABILITY);
    bool hasVisibilityReport =
        _submittedReports.any((r) => r.type == ReportType.VISIBILITY_ACTIVITY);
    bool hasFeedbackReport =
        _submittedReports.any((r) => r.type == ReportType.FEEDBACK);

    return hasProductReport && hasVisibilityReport && hasFeedbackReport;
  }

  void _resetForm() {
    _commentController.clear();
    _quantityController.clear();
    _selectedProduct = null;
    _imageFile = null;
    _imageUrl = null;
  }

  Widget _buildReportForm() {
    switch (_selectedReportType) {
      case ReportType.PRODUCT_AVAILABILITY:
        return Column(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              const Center(
                child: Text(
                  'No products available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  border: OutlineInputBorder(),
                ),
                items: _products.map((product) {
                  return DropdownMenuItem(
                    value: product,
                    child: Text(product.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedProduct = value);
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case ReportType.VISIBILITY_ACTIVITY:
        return Column(
          children: [
            Center(
              child: _imageFile != null || _imageUrl != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        _imageFile != null
                            ? Image.file(
                                _imageFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                _imageUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _imageFile = null;
                              _imageUrl = null;
                            });
                          },
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case ReportType.FEEDBACK:
        return TextField(
          controller: _commentController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Feedback',
            hintText: 'Enter your feedback here...',
            border: OutlineInputBorder(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                            widget.journeyPlan.outlet.name,
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
                      widget.journeyPlan.outlet.address,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Report Type Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<ReportType>(
                      segments: const [
                        ButtonSegment(
                          value: ReportType.PRODUCT_AVAILABILITY,
                          label: Text('Product Availability'),
                          icon: Icon(Icons.inventory),
                        ),
                        ButtonSegment(
                          value: ReportType.VISIBILITY_ACTIVITY,
                          label: Text('Visibility Activity'),
                          icon: Icon(Icons.photo_camera),
                        ),
                        ButtonSegment(
                          value: ReportType.FEEDBACK,
                          label: Text('Feedback'),
                          icon: Icon(Icons.feedback),
                        ),
                      ],
                      selected: {_selectedReportType},
                      onSelectionChanged: (Set<ReportType> newSelection) {
                        setState(() {
                          _selectedReportType = newSelection.first;
                          _resetForm();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Report Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportForm(),
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
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Submit Report'),
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
}
