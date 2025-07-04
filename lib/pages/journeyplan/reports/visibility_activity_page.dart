import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/visibilityReport_model.dart';
import 'package:woosh/pages/journeyplan/reports/base_report_page.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class VisibilityActivityPage extends BaseReportPage {
  const VisibilityActivityPage({
    super.key,
    required super.journeyPlan,
  }) : super(reportType: ReportType.VISIBILITY_ACTIVITY);

  @override
  State<VisibilityActivityPage> createState() => _VisibilityActivityPageState();
}

class _VisibilityActivityPageState extends State<VisibilityActivityPage>
    with BaseReportPageMixin, WidgetsBindingObserver {
  File? _imageFile;
  String? _imageUrl;
  bool _isUploading = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    // Clear image cache when memory is low
    ImageCache().clear();
    ImageCache().clearLiveImages();
    ApiCache.clear();
    // Clear local image file if it exists
    if (_imageFile != null) {
      _imageFile = null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrl = null;
      });

      // Start upload immediately
      _uploadImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      // Show upload progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 30),
          backgroundColor: Colors.white,
        ),
      );

      // Direct upload without any optimization - let Cloudinary handle it
      final imageUrl = await ApiService.uploadImage(_imageFile!);

      // Clear progress indicator
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        setState(() {
          _imageUrl = imageUrl;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);

        // Use API service's network error handler
        if (e.toString().contains('SocketException') ||
            e.toString().contains('XMLHttpRequest error')) {
          ApiService.handleNetworkError(e);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
        }
      }
    }
  }

  @override
  Future<void> onSubmit() async {
    if (_imageFile == null && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo')),
      );
      return;
    }

    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait for image upload to complete')),
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

    // Only include comment if not empty
    final comment = commentController.text.trim();

    final report = Report(
      type: ReportType.VISIBILITY_ACTIVITY,
      journeyPlanId: widget.journeyPlan.id!,
      salesRepId: userId,
      clientId: widget.journeyPlan.client.id,
      visibilityReport: VisibilityReport(
        reportId: 0,
        comment: comment.isNotEmpty ? comment : null, // Skip empty comments
        imageUrl: _imageUrl,
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
              'Visibility Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: _imageFile != null || _imageUrl != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(
                          _imageFile!,
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
                      onPressed: _isUploading ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Take Photo'),
                    ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comments',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
