import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/visibilityReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class VisibilityReportPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onReportSubmitted;

  const VisibilityReportPage({
    super.key,
    required this.journeyPlan,
    this.onReportSubmitted,
  });

  @override
  State<VisibilityReportPage> createState() => _VisibilityReportPageState();
}

class _VisibilityReportPageState extends State<VisibilityReportPage>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  bool _isUploading = false;
  File? _imageFile;
  String? _imageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Optimize image quality
        maxWidth: 700, // Limit image size
      );
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      // Read the image file
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Calculate new dimensions while maintaining aspect ratio
      int width = image.width;
      int height = image.height;
      const maxDimension = 800; // Reduced from 1200 to 800

      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
      }

      // Resize the image with better quality settings
      final resized = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.cubic, // Better quality interpolation
      );

      // Try progressive compression
      int quality = 85;
      List<int> compressedBytes = img.encodeJpg(resized, quality: quality);

      // If still too large, reduce quality further
      while (compressedBytes.length > 100 * 1024 && quality > 60) {
        // Target 100KB
        quality -= 5;
        compressedBytes = img.encodeJpg(resized, quality: quality);
      }

      // Create a temporary file for the compressed image
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      // Log compression results
      final originalSize = bytes.length;
      final compressedSize = compressedBytes.length;
      final compressionRatio =
          (compressedSize / originalSize * 100).toStringAsFixed(1);

      print('📊 Image compression results:');
      print('Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      print(
          'Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB');
      print('Compression ratio: $compressionRatio%');
      print('New dimensions: ${width}x$height');
      print('Final quality: $quality%');

      return tempFile;
    } catch (e) {
      print('❌ Image compression failed: $e');
      return null;
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    final stopwatch = Stopwatch()..start();
    setState(() {
      _isUploading = true;
      _uploadProgress = 'Preparing image...';
    });

    try {
      // Log original file size
      final originalSize = await _imageFile!.length();
      print(
          '📸 Original image size: ${(originalSize / 1024).toStringAsFixed(2)} KB');

      // Compress image
      setState(() => _uploadProgress = 'Compressing image...');
      final compressedFile = await _compressImage(_imageFile!);

      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Update progress
      setState(() => _uploadProgress = 'Uploading image...');

      // Upload compressed image
      final imageUrl = await ApiService.uploadImage(compressedFile);
      stopwatch.stop();

      print('✅ Image upload completed in ${stopwatch.elapsedMilliseconds}ms');
      print('🔗 Image URL: $imageUrl');

      // Clean up temporary file
      await compressedFile.delete();

      setState(() {
        _imageUrl = imageUrl;
        _isUploading = false;
        _uploadProgress = null;
      });
      return imageUrl;
    } catch (e) {
      stopwatch.stop();
      print('❌ Image upload failed after ${stopwatch.elapsedMilliseconds}ms');
      print('Error details: $e');

      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    final stopwatch = Stopwatch()..start();
    print('📝 Starting report submission process');

    if (_imageFile == null &&
        _imageUrl == null &&
        _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an image or comment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Optimistically show success
      widget.onReportSubmitted?.call();

      String? imageUrl;
      String? imageError;

      // Upload image if present
      if (_imageFile != null) {
        print('🖼️ Starting image upload');
        try {
          imageUrl = await _uploadImage();
          print(
              '🖼️ Image upload completed: ${imageUrl != null ? 'Success' : 'Failed'}');
        } catch (error) {
          print('❌ Image upload error: $error');
          if (error.toString().contains('SocketException') ||
              error.toString().contains('XMLHttpRequest error')) {
            imageError =
                'No internet connection. Image will be uploaded when online.';
          } else {
            imageError = error.toString();
          }
        }
      }

      // Get sales rep data
      final box = GetStorage();
      final salesRepData = box.read('salesRep');
      final int? salesRepId =
          salesRepData is Map<String, dynamic> ? salesRepData['id'] : null;

      if (salesRepId == null) {
        throw Exception(
            "User not authenticated: Could not determine salesRep ID");
      }

      print(
          '📊 Creating report with image: ${imageUrl != null ? 'Yes' : 'No'}');

      // Create and submit report
      Report report = Report(
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

      try {
        print('📤 Submitting report to API');
        await _apiService.submitReport(report);
        print('✅ Report submitted successfully');
      } catch (e) {
        print('❌ Report submission error: $e');
        if (e.toString().contains('SocketException') ||
            e.toString().contains('XMLHttpRequest error')) {
          // Store report locally for later sync
          // TODO: Implement local storage for offline reports
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No internet connection. Report will be submitted when online.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        rethrow;
      }

      stopwatch.stop();
      print('⏱️ Total submission time: ${stopwatch.elapsedMilliseconds}ms');

      if (mounted) {
        // Show success with animation
        await _animationController.reverse();
        Navigator.pop(context);

        // Show appropriate success message
        if (imageError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(imageError),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report submitted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      stopwatch.stop();
      print(
          '❌ Total submission failed after ${stopwatch.elapsedMilliseconds}ms');
      print('Error details: $e');

      if (mounted) {
        String errorMessage = 'Error submitting report';
        if (e.toString().contains('SocketException') ||
            e.toString().contains('XMLHttpRequest error')) {
          errorMessage =
              'No internet connection. Please try again when online.';
        } else {
          errorMessage = 'Error submitting report: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitReport,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Visibility Activity Report',
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Outlet Info Card with shimmer effect
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

              // Visibility Report Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _imageFile != null || _imageUrl != null
                            ? Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Hero(
                                    tag: 'visibility_image',
                                    child: _imageFile != null
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
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 200,
                                                width: double.infinity,
                                                color: Colors.grey.shade200,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
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
                                label: const Text('Take Photo'),
                              ),
                      ),
                      if (_isUploading && _uploadProgress != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(),
                        const SizedBox(height: 4),
                        Text(
                          _uploadProgress!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comment',
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
                                    SizedBox(width: 12),
                                    Text('Submitting...'),
                                  ],
                                )
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
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
