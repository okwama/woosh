import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:camera_android_camerax/camera_android_camerax.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/pages/journeyplan/reports_orders_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _isWithinGeofence = false;
  double _distanceToOutlet = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Camera-related variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraVisible = false;

  // Geofencing constants
  static const double GEOFENCE_RADIUS_METERS = 5.0; // 5 meters radius
  static const Duration LOCATION_UPDATE_INTERVAL = Duration(seconds: 5);

  String _currentAddress = 'Fetching address...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentPosition();
    _initializeCamera();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _positionStreamSubscription?.cancel();
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

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
        status: JourneyPlan.STATUS_CHECKED_IN,
        checkInTime: DateTime.now(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        imageUrl: imageUrl,
      );

      // Close loading indicator
      Navigator.pop(context);

      if (widget.onCheckInSuccess != null) {
        widget.onCheckInSuccess!(updatedPlan);
      }

      // Show success dialog with details
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Check-in Successful!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outlet: ${updatedPlan.outlet.name}'),
              const SizedBox(height: 8),
              Text('Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}'),
              const SizedBox(height: 8),
              Text('Location: $_currentAddress'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('View Reports'),
            ),
          ],
        ),
      );

      // Navigate to reports page
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportsOrdersPage(journeyPlan: updatedPlan),
        ),
      );
    } catch (e) {
      print('Check-in error: $e');
      // Close loading indicator if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check-in: $e'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  // Calculate distance between two points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Check if user is within geofence
  Future<bool> _checkGeofence() async {
    try {
      if (_currentPosition == null) {
        print('Current position is null');
        return false;
      }

      // Get outlet coordinates from the journey plan
      final outletLat = widget.journeyPlan.outlet.latitude;
      final outletLon = widget.journeyPlan.outlet.longitude;

      if (outletLat == null || outletLon == null) {
        print('Outlet coordinates not available');
        // Only show notification if we're in the check-in process
        if (_isCheckingIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Outlet location data is missing. Please contact support.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Calculate distance to outlet
      _distanceToOutlet = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        outletLat,
        outletLon,
      );

      print('Distance to outlet: $_distanceToOutlet meters');

      // Check if distance is within acceptable range
      final isWithinRange = _distanceToOutlet <= GEOFENCE_RADIUS_METERS;

      // Log geofence status for debugging
      print(
          'Geofence status: ${isWithinRange ? "Within range" : "Outside range"}');

      return isWithinRange;
    } catch (e) {
      print('Error checking geofence: $e');
      // Only show error notification if we're in the check-in process
      if (_isCheckingIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _getCurrentPosition() async {
    setState(() {
      _isFetchingLocation = true;
      _currentAddress = 'Fetching address...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Location services are disabled. Please enable them.'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied.'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in settings.',
            ),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _currentAddress =
                '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
          });
        } else {
          setState(() {
            _currentAddress = 'Address not available';
          });
        }
      } catch (e) {
        print('Error getting address: $e');
        setState(() {
          _currentAddress = 'Address not available';
        });
      }

      setState(() {
        _currentPosition = position;
        _isFetchingLocation = false;
      });

      // Check geofence after getting position
      _isWithinGeofence = await _checkGeofence();
      setState(() {}); // Update UI to reflect geofence status
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isFetchingLocation = false;
        _currentAddress = 'Location not available';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startLocationUpdates() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update if moved more than 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _checkGeofence();
    }, onError: (error) {
      print('Error in location stream: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Future<void> _checkIn() async {
    try {
      setState(() {
        _isCheckingIn = true;
      });

      // Check geofence before proceeding
      if (!await _checkGeofence()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You must be within ${GEOFENCE_RADIUS_METERS} meters of the outlet to check in. Current distance: ${_distanceToOutlet.toStringAsFixed(1)} meters',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Check-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to check in at this location?'),
              const SizedBox(height: 8),
              Text(
                'Distance to outlet: ${_distanceToOutlet.toStringAsFixed(1)} meters',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Check In'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Capture image
      final imageFile = await _captureImage();
      if (imageFile == null) {
        throw Exception('Failed to capture image');
      }

      // Upload image
      final imageUrl = await ApiService.uploadImage(imageFile);
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Update journey plan
      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
        status: JourneyPlan.STATUS_CHECKED_IN,
        checkInTime: DateTime.now(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully checked in!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to reports page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportsOrdersPage(journeyPlan: updatedPlan),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  Future<File?> _captureImage() async {
    try {
      if (kIsWeb) {
        // For web platforms, use ImagePicker
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image == null) {
          throw Exception('No image was selected');
        }

        // Convert XFile to File
        final bytes = await image.readAsBytes();
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/image.jpg');
        await tempFile.writeAsBytes(bytes);
        return tempFile;
      } else {
        // For mobile platforms, use camera
        if (!_isCameraInitialized) {
          throw Exception('Camera is not initialized');
        }

        final image = await _cameraController!.takePicture();
        return File(image.path);
      }
    } catch (e) {
      print('Error capturing image: $e');
      rethrow;
    }
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
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.journeyPlan.status == 1
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.journeyPlan.status == 1
                            ? 'Checked In'
                            : 'Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

                    // Current Location with Geofence Status
                    _buildInfoItem(
                      'Current Location',
                      _isFetchingLocation
                          ? 'Fetching location...'
                          : _currentAddress,
                      Icons.my_location,
                    ),
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isWithinGeofence
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isWithinGeofence
                                  ? Icons.check_circle
                                  : Icons.warning,
                              size: 16,
                              color:
                                  _isWithinGeofence ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isWithinGeofence
                                  ? 'Within check-in range'
                                  : 'Outside check-in range',
                              style: TextStyle(
                                color: _isWithinGeofence
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distance to outlet: ${_distanceToOutlet.toStringAsFixed(1)} meters',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    if (widget.journeyPlan.status == 1)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportsOrdersPage(
                                  journeyPlan: widget.journeyPlan),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assessment, size: 18),
                        label: const Text('View Reports'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: (_isCheckingIn || !_isWithinGeofence)
                            ? null
                            : _checkIn,
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
