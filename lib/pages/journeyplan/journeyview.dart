import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera_android_camerax/camera_android_camerax.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/pages/journeyplan/reports_orders_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class JourneyView extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final Function(JourneyPlan)? onCheckInSuccess;

  const JourneyView({
    Key? key,
    required this.journeyPlan,
    this.onCheckInSuccess,
  }) : super(key: key);

  @override
  _JourneyViewState createState() => _JourneyViewState();
}

class _JourneyViewState extends State<JourneyView> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  Position? _currentPosition;
  bool _isCheckingIn = false;
  bool _isFetchingLocation = false;

  // Camera-related variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentPosition();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission first
      final status = await Permission.camera.request();
      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Camera permission is required for check-in. Please grant permission in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      } else {
        throw Exception('No cameras available');
      }
    } catch (e) {
      print('Failed to initialize camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize camera: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showCameraDialog() async {
    if (!_isCameraInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera is not ready. Please try again.')),
      );
      return;
    }

    setState(() {
      _isCameraVisible = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 400,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(_cameraController!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isCameraVisible = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  FloatingActionButton(
                    onPressed: () async {
                      try {
                        final image = await _cameraController!.takePicture();
                        setState(() {
                          _isCameraVisible = false;
                        });
                        Navigator.pop(context);
                        await _processImage(File(image.path));
                      } catch (e) {
                        print('Error capturing image: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to capture image: $e')),
                        );
                      }
                    },
                    child: const Icon(Icons.camera),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isCheckingIn = true;
    });

    try {
      print('Uploading image...');
      final imageUrl = await ApiService.uploadImage(imageFile);
      print('Image uploaded successfully: $imageUrl');

      if (widget.journeyPlan.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey ID is required to check in.')),
        );
        return;
      }

      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
        status: 'checked_in',
        checkInTime: DateTime.now(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        imageUrl: imageUrl,
      );

      if (widget.onCheckInSuccess != null) {
        widget.onCheckInSuccess!(updatedPlan);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportsOrdersPage(journeyPlan: updatedPlan),
        ),
      );
    } catch (e) {
      print('Check-in error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check-in: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isCheckingIn = false;
      });
    }
  }

  Future<void> _checkIn() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Check-In'),
        content: const Text(
            'A picture will be taken to confirm your check-in. Proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _showCameraDialog();
  }

  Future<void> _getCurrentPosition() async {
    setState(() {
      _isFetchingLocation = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Location services are disabled. Please enable them.')),
      );
      setState(() {
        _isFetchingLocation = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        setState(() {
          _isFetchingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable them in settings.')),
      );
      setState(() {
        _isFetchingLocation = false;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
      _isFetchingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Check-In'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12.0),
                    topRight: Radius.circular(12.0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.journeyPlan.outlet.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dotted line separator
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: List.generate(
                    20,
                    (index) => Expanded(
                      child: Container(
                        color: index % 2 == 0
                            ? Colors.grey.shade300
                            : Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date
                    _buildInfoItem(
                      'Date',
                      dateFormatter.format(widget.journeyPlan.date),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),

                    // Location
                    _buildInfoItem(
                      'Location',
                      widget.journeyPlan.outlet.address,
                      Icons.location_on,
                    ),

                    const SizedBox(height: 8),

                    // Current Location
                    _buildInfoItem(
                      'Current Location',
                      _isFetchingLocation
                          ? 'Fetching location...'
                          : _currentPosition != null
                              ? '${_currentPosition!.latitude}, ${_currentPosition!.longitude}'
                              : 'Location not available',
                      Icons.my_location,
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12.0),
                    bottomRight: Radius.circular(12.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isCheckingIn ? null : _checkIn,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
