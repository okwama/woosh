import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:intl/intl.dart';
import 'package:woosh/pages/journeyplan/reports/reportMain_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
// ignore: unnecessary_import
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:woosh/services/universal_file.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class JourneyView extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final Function(JourneyPlan)? onCheckInSuccess;

  const JourneyView({
    super.key,
    required this.journeyPlan,
    this.onCheckInSuccess,
  });

  @override
  _JourneyViewState createState() => _JourneyViewState();
}

class _JourneyViewState extends State<JourneyView> with WidgetsBindingObserver {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isCheckingIn = false;
  bool _isFetchingLocation = false;
  bool _isWithinGeofence = false;
  double _distanceToClient = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Captured image file variable
  File? _capturedImage;
  // ignore: unused_field
  String? _imageUrl;

  // Notes-related variables
  final TextEditingController _notesController = TextEditingController();
  final bool _isEditingNotes = false;
  final bool _isSavingNotes = false;

  // Geofencing constants
  static const double GEOFENCE_RADIUS_METERS =
      20037500.0; // Half the Earth's circumference in meters
  static const Duration LOCATION_UPDATE_INTERVAL = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize notes controller with existing notes
    _notesController.text = widget.journeyPlan.notes ?? '';

    // If the journey plan is already checked in or in progress, use the stored location
    if (widget.journeyPlan.isCheckedIn || widget.journeyPlan.isInTransit) {
      _useCheckInLocation();
    } else {
      // Only get current position if journey is pending
      _getCurrentPosition();
    }

    // Determine journey state and handle accordingly
    if (widget.journeyPlan.isPending) {
      // Only start location updates for pending journeys
      _startLocationUpdates();
    } else if (widget.journeyPlan.isCheckedIn) {
      // If journey is checked in but not in progress, try to update status
      print(
          'Found journey in checked-in status, attempting to update to in-progress');
      _fixJourneyStatus();
    }
  }

  @override
  void dispose() {
    // Cancel location updates
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Dispose of text controller
    _notesController.dispose();

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No camera controller logic needed
  }

  @override
  void didUpdateWidget(JourneyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If journey plan status changes to checked in, stop location updates
    if (!oldWidget.journeyPlan.isCheckedIn && widget.journeyPlan.isCheckedIn) {
      _positionStreamSubscription?.cancel();
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Clear image cache when memory is low
    ImageCache().clear();
    ImageCache().clearLiveImages();
    ApiCache.clear();
    // No camera resources to release
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case JourneyPlan.statusInProgress:
        return Colors.blue;
      case JourneyPlan.statusCheckedIn:
        return Colors.orange;
      case JourneyPlan.statusCompleted:
        return Colors.green;
      case JourneyPlan.statusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case JourneyPlan.statusInProgress:
        return 'In Progress';
      case JourneyPlan.statusCheckedIn:
        return 'Checked In';
      case JourneyPlan.statusCompleted:
        return 'Completed';
      case JourneyPlan.statusCancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  void _checkIn() async {
    try {
      setState(() {
        _isCheckingIn = true;
      });

      // First check if there's an active visit
      final activeVisit = await ApiService.getActiveVisit();
      print('Current journey plan status: ${widget.journeyPlan.status}');
      print('Active visit found: ${activeVisit != null}');

      // Check if current journey plan is already in progress
      if (widget.journeyPlan.status == JourneyPlan.statusInProgress) {
        Get.snackbar(
          'Already Checked In',
          'You are already checked in to this visit.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // If there's an active visit and it's not this one, and it's either checked in or in progress
      if (activeVisit != null &&
          activeVisit.id != widget.journeyPlan.id &&
          (activeVisit.status == JourneyPlan.statusInProgress || 
           activeVisit.status == JourneyPlan.statusCheckedIn)) {
        Get.dialog(
          AlertDialog(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Visit Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You have an active visit with:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeVisit.clientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(activeVisit.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(activeVisit.status),
                    style: TextStyle(
                      color: _getStatusColor(activeVisit.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please complete your current visit before starting a new one.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/journey-view', arguments: activeVisit);
                },
                child: const Text('Go to Active Visit'),
              ),
            ],
          ),
        );
        print('Active visit found: ${activeVisit.id}');
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Final validation - Double check active visit status right before proceeding
      final finalActiveVisit = await ApiService.getActiveVisit();
      if (finalActiveVisit != null && 
          finalActiveVisit.id != widget.journeyPlan.id && 
          (finalActiveVisit.status == JourneyPlan.statusInProgress || 
           finalActiveVisit.status == JourneyPlan.statusCheckedIn)) {
        Get.snackbar(
          'Cannot Check In',
          'Another visit became active. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Check geofence before proceeding
      if (!await _checkGeofence()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You must be closer to the client to check in. Please move within ${(GEOFENCE_RADIUS_METERS / 1000).toStringAsFixed(0)} kilometers.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Open camera using image_picker
      await _openCameraAndCapture();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isCheckingIn = false;
      });
    }
  }

  Future<void> _openCameraAndCapture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      _capturedImage = File(image.path);
      _imageUrl = null;

      // Show confirmation dialog
      await _showConfirmationDialog(_capturedImage);
    } catch (e) {
      print('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  Future<void> _showConfirmationDialog(File? imageFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Confirm Check-in Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (imageFile != null)
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Image.file(imageFile),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                      // Retake photo
                      _openCameraAndCapture();
                    },
                    child: const Text('Retake'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      // Proceed with check-in
      await _submitCheckIn();
    } else if (confirmed == false) {
      // Will retake photo, so don't reset _isCheckingIn
    } else {
      // Dialog was dismissed some other way
      setState(() {
        _isCheckingIn = false;
      });
    }
  }

  Future<void> _submitCheckIn() async {
    try {
      // First upload the image
      print('Uploading image...');
      final dynamic imageFile = _capturedImage;
      final imageUrl = await ApiService.uploadImage(imageFile);
      print('Image uploaded successfully: $imageUrl');

      if (widget.journeyPlan.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Journey ID is required to check in.')),
          );
        }
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Ensure we pass the clientId
      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusCheckedIn,
        checkInTime: DateTime.now(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        imageUrl: imageUrl,
      );

      // Immediately update to In Progress status
      final inProgressPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusInProgress,
      );

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (widget.onCheckInSuccess != null && mounted) {
        widget.onCheckInSuccess!(inProgressPlan);
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
              Text('Client: ${inProgressPlan.client.name}'),
              const SizedBox(height: 8),
              Text('Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}'),
              const SizedBox(height: 8),
              Text('Location: $_currentAddress'),
              const SizedBox(height: 8),
              const Text('Status: In Progress'),
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
          builder: (context) => ReportsOrdersPage(journeyPlan: inProgressPlan),
        ),
      );
    } catch (e) {
      print('Error checking in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking in: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  // Calculate distance using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    // Convert to radians
    double lat1Rad = lat1 * pi / 180;
    double lat2Rad = lat2 * pi / 180;
    double deltaLat = (lat2 - lat1) * pi / 180;
    double deltaLon = (lon2 - lon1) * pi / 180;

    // Haversine formula
    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Calculate distance in meters
    double distance = earthRadius * c;

    print('\nDebug - Distance calculation:');
    print('From: ($lat1, $lon1)');
    print('To: ($lat2, $lon2)');
    print('Distance: ${distance.toStringAsFixed(2)} meters');
    print('Geofence radius: $GEOFENCE_RADIUS_METERS meters');

    return distance;
  }

  // Check if user is within geofence
  Future<bool> _checkGeofence() async {
    try {
      // If journey is already checked in or in progress, we don't need geofence check
      if (widget.journeyPlan.isCheckedIn ||
          widget.journeyPlan.isInTransit ||
          widget.journeyPlan.isCompleted) {
        print('Debug - Journey is already checked in or in progress');
        _isWithinGeofence = true;
        return true;
      }

      if (_currentPosition == null) {
        print('Debug - Current position is null');
        return false;
      }

      // Get client coordinates from the journey plan
      final clientLat = widget.journeyPlan.client.latitude;
      final clientLon = widget.journeyPlan.client.longitude;

      // Add debug logging
      print('\nDebug - Current Position:');
      print('Latitude: ${_currentPosition!.latitude}');
      print('Longitude: ${_currentPosition!.longitude}');
      print('Debug - Client Position:');
      print('Latitude: $clientLat');
      print('Longitude: $clientLon');

      if (clientLat == null || clientLon == null) {
        print('Debug - Client coordinates not available');
        return false;
      }

      // Calculate distance to client
      _distanceToClient = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        clientLat,
        clientLon,
      );

      // Check if distance is within acceptable range
      final isWithinRange = _distanceToClient <= GEOFENCE_RADIUS_METERS;

      print(
          'Debug - Geofence status: ${isWithinRange ? "Within range" : "Outside range"}');
      print(
          'Distance to client: ${_distanceToClient.toStringAsFixed(2)} meters');

      // Update the UI state
      if (mounted) {
        setState(() {
          _isWithinGeofence = isWithinRange;
        });
      }

      return isWithinRange;
    } catch (e) {
      print('Debug - Error checking geofence: $e');
      return false;
    }
  }

  Future<void> _getCurrentPosition() async {
    if (!mounted) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      // 1. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      // 2. Check services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      // 3. Get position with balanced accuracy and faster timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;

      // 4. Validate position
      if (position.latitude == 0 && position.longitude == 0) {
        throw Exception('Invalid position received');
      }

      print('Debug - Got position with accuracy: ${position.accuracy} meters');

      setState(() {
        _currentPosition = position;
      });

      // 5. Get address and check geofence
      await _getAddressFromLatLng(position.latitude, position.longitude);
      await _checkGeofence();
    } catch (e) {
      print('Debug - Error getting position: $e');
      if (!mounted) return;
      setState(() {
        _currentAddress = 'Could not determine location';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _startLocationUpdates() {
    // Cancel any existing subscription
    _positionStreamSubscription?.cancel();

    // Only start updates if journey is pending
    if (widget.journeyPlan.isPending) {
      print('Starting location updates for pending journey');
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          // Only update position if widget is still mounted and journey is still pending
          if (mounted && widget.journeyPlan.isPending) {
            print('\nDebug - New position received:');
            print('Latitude: ${position.latitude}');
            print('Longitude: ${position.longitude}');
            print('Accuracy: ${position.accuracy} meters');
            print('Previous geofence status: $_isWithinGeofence');

            setState(() {
              _currentPosition = position;
            });

            // Check geofence and log the result
            _checkGeofence().then((isWithinRange) {
              print('Debug - Geofence check completed:');
              print('Is within range: $isWithinRange');
              print('New geofence status: $_isWithinGeofence');
              print(
                  'Distance to client: ${_distanceToClient.toStringAsFixed(2)} meters\n');
            });
          }
        },
        onError: (error) {
          print('Error in location stream: $error');
          if (mounted && widget.journeyPlan.isPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating location: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        cancelOnError: false,
      );
    }
  }

  // Handle completion when all reports are submitted
  Future<void> _handleAllReportsSubmitted() async {
    try {
      // Update journey status to completed
      final completedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusCompleted,
      );

      if (!mounted) return;

      // Show completion dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.task_alt, color: Colors.green),
              SizedBox(width: 8),
              Text('Journey Completed!'),
            ],
          ),
          content: const Text(
              'All reports have been submitted successfully. The journey plan is now complete.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Update parent if callback exists
      if (widget.onCheckInSuccess != null) {
        widget.onCheckInSuccess!(completedPlan);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete journey: $e'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fix journey status if it's stuck in checked in instead of in progress
  Future<void> _fixJourneyStatus() async {
    try {
      if (widget.journeyPlan.id == null) return;

      // Only update if the journey is actually in checked-in status
      if (!widget.journeyPlan.isCheckedIn) {
        print('Journey not in checked-in status, no need to fix status');
        return;
      }

      print('Fixing journey status: changing from checked-in to in-progress');

      // Update to In Progress status
      final inProgressPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusInProgress,
      );

      if (widget.onCheckInSuccess != null && mounted) {
        widget.onCheckInSuccess!(inProgressPlan);
      }
    } catch (e) {
      print('Error fixing journey status: $e');
      // Don't show an error to the user as this is a background fix
    }
  }

  // Get address from latitude and longitude
  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    if (!mounted) return;

    setState(() {
      _isFetchingLocation = true;
      // Set a default value immediately in case of errors
      _currentAddress = 'Check-in location';
    });

    // Validate inputs
    if (latitude == 0 && longitude == 0) {
      print('Invalid coordinates: latitude and longitude are both 0');
      setState(() {
        _isFetchingLocation = false;
      });
      return;
    }

    try {
      print('Attempting to get address for: $latitude, $longitude');

      // Create a fallback address immediately
      final fallbackAddress =
          'Location at (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';

      // Try to get the address but be prepared for failure
      try {
        // Add a delay before geocoding to avoid rate limiting issues
        await Future.delayed(const Duration(milliseconds: 300));

        final List<Placemark> placemarks = await placemarkFromCoordinates(
          latitude,
          longitude,
          localeIdentifier: 'en_US',
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Geocoding timed out');
            throw TimeoutException('Geocoding operation timed out');
          },
        );

        if (!mounted) return;

        if (placemarks.isNotEmpty) {
          // Safely extract address components with null checks
          final Placemark place = placemarks.first;

          final String street = place.street ?? '';
          final String locality = place.locality ?? '';
          final String subLocality = place.subLocality ?? '';

          String addressText;
          if (street.isNotEmpty) {
            addressText = street;
            if (subLocality.isNotEmpty || locality.isNotEmpty) {
              addressText +=
                  ', ${subLocality.isNotEmpty ? subLocality : locality}';
            }
          } else if (subLocality.isNotEmpty || locality.isNotEmpty) {
            addressText = subLocality.isNotEmpty ? subLocality : locality;
          } else {
            // If no meaningful address components, use the fallback
            addressText = fallbackAddress;
          }

          setState(() {
            _currentAddress = addressText;
            _isFetchingLocation = false;
          });

          print('Successfully retrieved address: $addressText');
          return;
        }
      } catch (geocodingError) {
        // Just log the error and continue to use the fallback
        print('Geocoding error: $geocodingError');
      }

      // If we get here, either the geocoding failed or returned no results
      // Use the fallback address
      if (!mounted) return;

      setState(() {
        _currentAddress = fallbackAddress;
        _isFetchingLocation = false;
      });
    } catch (e) {
      print('Error in _getAddressFromLatLng: $e');

      if (!mounted) return;

      // Final fallback
      setState(() {
        _currentAddress = 'Location found';
        _isFetchingLocation = false;
      });
    }
  }

  // Use the check-in location from the journey plan
  void _useCheckInLocation() {
    if (widget.journeyPlan.latitude != null &&
        widget.journeyPlan.longitude != null) {
      // Add debug logging
      print('Debug - Using Check-in Location:');
      print('Journey Plan Latitude: ${widget.journeyPlan.latitude}');
      print('Journey Plan Longitude: ${widget.journeyPlan.longitude}');
      print('Client Latitude: ${widget.journeyPlan.client.latitude}');
      print('Client Longitude: ${widget.journeyPlan.client.longitude}');

      // Create a position from the stored coordinates
      _currentPosition = Position(
        latitude: widget.journeyPlan.latitude!,
        longitude: widget.journeyPlan.longitude!,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
        isMocked: false,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      // Set a default address immediately
      setState(() {
        _currentAddress =
            'Location: ${widget.journeyPlan.latitude!.toStringAsFixed(6)}, ${widget.journeyPlan.longitude!.toStringAsFixed(6)}';
      });

      // Try to get a more detailed address
      _getAddressFromLatLng(
          widget.journeyPlan.latitude!, widget.journeyPlan.longitude!);

      print(
          'Using check-in location: Lat ${widget.journeyPlan.latitude}, Lng ${widget.journeyPlan.longitude}');
    } else {
      print(
          'No check-in location found in journey plan, getting current position instead');
      _getCurrentPosition();
    }
  }

  // Update client location with current coordinates
  Future<void> _updateClientLocation() async {
    if (_currentPosition == null) {
      Get.snackbar(
        'Error',
        'Current location not available',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      setState(() {
        _isFetchingLocation = true;
      });

      await ApiService.updateClientLocation(
        clientId: widget.journeyPlan.client.id,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      Get.snackbar(
        'Success',
        'Client location updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh the journey plan to get updated client data
      await _refreshJourneyStatus();
    } catch (e) {
      print('Error updating client location: $e');
      Get.snackbar(
        'Error',
        'Failed to update client location',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Journey Check-In',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing...'),
                  duration: Duration(seconds: 1),
                ),
              );

              // Refresh location if journey is pending
              if (widget.journeyPlan.isPending) {
                _getCurrentPosition();
              } else {
                // Refresh journey status from the API
                _refreshJourneyStatus();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Status Card
            Card(
              margin: const EdgeInsets.only(bottom: 6.0),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: widget.journeyPlan.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: widget.journeyPlan.statusColor,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Journey Status:',
                      style: TextStyle(
                        color: widget.journeyPlan.statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.journeyPlan.statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.journeyPlan.statusText.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Journey Details Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6.0),
                        topRight: Radius.circular(6.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.journeyPlan.client.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // Left column
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildInfoItem(
                                    'Date',
                                    dateFormatter
                                        .format(widget.journeyPlan.date),
                                    Icons.calendar_today,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildInfoItem(
                                    'Location',
                                    widget.journeyPlan.client.address,
                                    Icons.location_on,
                                  ),
                                  const SizedBox(height: 6),
                                  if (widget
                                      .journeyPlan.showUpdateLocation) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isFetchingLocation
                                                ? null
                                                : _updateClientLocation,
                                            icon: const Icon(
                                                Icons.upload_rounded,
                                                size: 14),
                                            label: Text(
                                              _isFetchingLocation
                                                  ? 'Updating...'
                                                  : 'Update Location',
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .primaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Right column
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildInfoItem(
                                    // Show different label based on journey status
                                    widget.journeyPlan.isPending
                                        ? 'Current Location'
                                        : 'Check-in Location',
                                    _isFetchingLocation
                                        ? 'Fetching location...'
                                        : _currentAddress ??
                                            'Location not available',
                                    Icons.my_location,
                                  ),
                                  if (_currentPosition != null) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isWithinGeofence
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isWithinGeofence
                                                ? Icons.check_circle
                                                : Icons.warning,
                                            size: 12,
                                            color: _isWithinGeofence
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              _isWithinGeofence
                                                  ? 'Within range'
                                                  : 'Outside range',
                                              style: TextStyle(
                                                color: _isWithinGeofence
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isWithinGeofence)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          '${_distanceToClient.toStringAsFixed(1)}m away',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Notes section
                        const SizedBox(height: 12),
                        _buildNotesSection(),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6.0),
                        bottomRight: Radius.circular(6.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.journeyPlan.isCheckedIn ||
                            widget.journeyPlan.isInTransit ||
                            widget.journeyPlan.isCompleted)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportsOrdersPage(
                                    journeyPlan: widget.journeyPlan,
                                    onAllReportsSubmitted:
                                        _handleAllReportsSubmitted,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.assessment, size: 14),
                            label: const Text('View Reports'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          )
                        else if (widget.journeyPlan.isPending)
                          ElevatedButton.icon(
                            onPressed: (_isCheckingIn || !_isWithinGeofence)
                                ? null
                                : _checkIn,
                            icon: const Icon(Icons.camera_alt, size: 14),
                            label: const Text('Check In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 1),
              if (_isFetchingLocation && label == 'Current Location')
                Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fetching location...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.2,
                    color: value.startsWith('Error') ||
                            value.contains('denied') ||
                            value == 'Address not available'
                        ? Colors.red.shade700
                        : Colors.black87,
                  ),
                  // Allow multiple lines for address
                  maxLines: label.contains('Location') ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Refresh journey status from the API
  Future<void> _refreshJourneyStatus() async {
    try {
      if (widget.journeyPlan.id == null) return;

      // Fetch updated journey plan
      final updatedPlan =
          await ApiService.getJourneyPlanById(widget.journeyPlan.id!);

      if (!mounted) return;

      // Update local state if needed
      if (updatedPlan != null && widget.onCheckInSuccess != null) {
        widget.onCheckInSuccess!(updatedPlan);
      }

      // Refresh location if checked in
      if (updatedPlan != null &&
          (updatedPlan.isCheckedIn || updatedPlan.isInTransit)) {
        _useCheckInLocation();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error refreshing journey status: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notes, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              'Notes',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 14),
              onPressed: () {
                _showEditNotesDialog();
              },
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: widget.journeyPlan.notes?.isNotEmpty == true
              ? Text(
                  widget.journeyPlan.notes!,
                  style: const TextStyle(fontSize: 12),
                )
              : Text(
                  'No notes added',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
        ),
      ],
    );
  }

  void _showEditNotesDialog() {
    final TextEditingController notesController = TextEditingController(
      text: widget.journeyPlan.notes ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: notesController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter notes about this journey plan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saving notes...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Call API to update notes
                final updatedJourneyPlan = await ApiService.updateJourneyPlan(
                  journeyId: widget.journeyPlan.id!,
                  clientId: widget.journeyPlan.client.id,
                  notes: notesController.text.trim(),
                  status: widget.journeyPlan.status,
                );

                // If the update was successful, rebuild the UI
                if (widget.onCheckInSuccess != null) {
                  widget.onCheckInSuccess!(updatedJourneyPlan);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notes saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save notes: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
