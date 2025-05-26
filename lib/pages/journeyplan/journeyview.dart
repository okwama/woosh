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
import 'package:camera/camera.dart';
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

  // Add these new variables at the top of the class
  Position? _cachedPosition;
  DateTime? _lastLocationUpdate;
  static const Duration LOCATION_CACHE_DURATION = Duration(seconds: 30);
  bool _isValidatingCheckIn = false;

  // Add new state variable for location status
  bool _isLocationPending = false;

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

  // Add this new method for parallel validation
  Future<bool> _validateCheckIn() async {
    if (_isValidatingCheckIn) return false;
    _isValidatingCheckIn = true;

    try {
      final results = await Future.wait([
        _checkGeofenceWithPending(),
        ApiService.getActiveVisit(),
      ], eagerError: false);

      final isWithinGeofence = results[0] as bool;
      final activeVisit = results[1] as JourneyPlan?;

      if (!isWithinGeofence) {
        Get.snackbar(
          'Too Far from Location',
          'Please move closer to the client location to check in.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return false;
      }

      if (activeVisit != null &&
          activeVisit.id != widget.journeyPlan.id &&
          (activeVisit.status == JourneyPlan.statusInProgress ||
              activeVisit.status == JourneyPlan.statusCheckedIn)) {
        Get.dialog(
          AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Active Visit Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have an active visit with ${activeVisit.client.name}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/journey-view', arguments: activeVisit);
                },
                child: const Text('Go to Active Visit'),
              ),
            ],
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('Validation error: $e');
      return false;
    } finally {
      _isValidatingCheckIn = false;
    }
  }

  // Modify the _checkIn method to handle unknown locations
  void _checkIn() async {
    if (_isCheckingIn) return;

    setState(() {
      _isCheckingIn = true;
    });

    try {
      // Run initial validations in parallel
      final validationResults = await Future.wait([
        // Check if already checked in
        Future.value(widget.journeyPlan.status == JourneyPlan.statusInProgress),
        // Check geofence with location pending option
        _checkGeofenceWithPending(),
        // Check active visit
        ApiService.getActiveVisit(),
      ], eagerError: false);

      final isAlreadyCheckedIn = validationResults[0] as bool;
      final geofenceResult = validationResults[1] as Map<String, dynamic>;
      final activeVisit = validationResults[2] as JourneyPlan?;

      // Handle validation results
      if (isAlreadyCheckedIn) {
        Get.snackbar(
          'Already Checked In',
          'You are already checked in to this visit.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // Handle geofence result
      if (!geofenceResult['isValid']) {
        if (geofenceResult['isPending']) {
          // Show location pending dialog
          final proceed = await _showLocationPendingDialog();
          if (!proceed) {
            setState(() {
              _isCheckingIn = false;
            });
            return;
          }
        } else {
          Get.snackbar(
            'Too Far',
            'Please move closer to the client location',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
          return;
        }
      }

      if (activeVisit != null &&
          activeVisit.id != widget.journeyPlan.id &&
          (activeVisit.status == JourneyPlan.statusInProgress ||
              activeVisit.status == JourneyPlan.statusCheckedIn)) {
        Get.dialog(
          AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Active Visit Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have an active visit with ${activeVisit.client.name}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/journey-view', arguments: activeVisit);
                },
                child: const Text('Go to Active Visit'),
              ),
            ],
          ),
        );
        return;
      }

      // Open camera with optimized settings
      await _openCameraAndCapture();
    } catch (e) {
      print('Check-in error: $e');
      Get.snackbar(
        'Error',
        'Failed to check in. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  // Add camera permission check method
  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  // Optimize camera capture with better error handling
  Future<void> _openCameraAndCapture() async {
    try {
      // Check camera permission first
      final hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        Get.snackbar(
          'Camera Access Required',
          'Please enable camera access in your device settings to check in.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Check if camera is available
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Get.snackbar(
          'Camera Not Available',
          'No camera found on your device. Please try again later.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker
          .pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          Get.snackbar(
            'Camera Timeout',
            'Taking too long to capture image. Please try again.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return null;
        },
      );

      if (image == null) {
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      _capturedImage = File(image.path);
      _imageUrl = null;

      // Show quick confirmation dialog
      await _showQuickConfirmationDialog(_capturedImage);
    } catch (e) {
      print('Error capturing image: $e');
      if (mounted) {
        Get.snackbar(
          'Camera Error',
          'Unable to access camera. Please check your camera permissions and try again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  // Optimize confirmation dialog
  Future<void> _showQuickConfirmationDialog(File? imageFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageFile != null)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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
      await _submitCheckIn();
    } else {
      setState(() {
        _isCheckingIn = false;
      });
    }
  }

  // Add new method for geofence check with pending status
  Future<Map<String, dynamic>> _checkGeofenceWithPending() async {
    try {
      // If journey is already in progress or checked in, always return valid
      if (widget.journeyPlan.isCheckedIn ||
          widget.journeyPlan.isInTransit ||
          widget.journeyPlan.isCompleted ||
          widget.journeyPlan.status == JourneyPlan.statusInProgress) {
        print(
            'Debug - Journey is already in progress or checked in, skipping geofence check');
        return {'isValid': true, 'isPending': false};
      }

      // Use cached position if available and recent
      if (_cachedPosition != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              LOCATION_CACHE_DURATION) {
        _currentPosition = _cachedPosition;
        print('Debug - Using cached position');
      } else {
        print('Debug - Getting fresh position');
        // Get fresh position without time limit
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('Debug - Position request timed out');
            return _cachedPosition ??
                Position(
                  latitude: 0,
                  longitude: 0,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );
          },
        );
        _cachedPosition = _currentPosition;
        _lastLocationUpdate = DateTime.now();
      }

      if (_currentPosition == null) {
        print('Debug - Current position is null');
        return {'isValid': false, 'isPending': true};
      }

      final clientLat = widget.journeyPlan.client.latitude;
      final clientLon = widget.journeyPlan.client.longitude;

      if (clientLat == null || clientLon == null) {
        print(
            'Debug - Client coordinates are null: Lat: $clientLat, Lon: $clientLon');
        return {'isValid': false, 'isPending': true};
      }

      print(
          'Debug - Current Position: Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}');
      print('Debug - Client Position: Lat: $clientLat, Lon: $clientLon');

      // Calculate distance using both methods to verify
      _distanceToClient = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        clientLat,
        clientLon,
      );

      // Also calculate using Geolocator for comparison
      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        clientLat,
        clientLon,
      );

      print(
          'Debug - Calculated Distance (Haversine): $_distanceToClient meters');
      print(
          'Debug - Calculated Distance (Geolocator): $distanceInMeters meters');
      print('Debug - Geofence Radius: $GEOFENCE_RADIUS_METERS meters');

      // Use the smaller of the two distances to be more lenient
      final actualDistance = _distanceToClient < distanceInMeters
          ? _distanceToClient
          : distanceInMeters;

      // Add a small buffer (10 meters) to account for GPS inaccuracy
      final isWithinRange = actualDistance <= (GEOFENCE_RADIUS_METERS + 10);

      print('Debug - Using distance: $actualDistance meters');
      print('Debug - Is within range: $isWithinRange');

      if (mounted) {
        setState(() {
          _isWithinGeofence = isWithinRange;
        });
      }

      return {'isValid': isWithinRange, 'isPending': false};
    } catch (e) {
      print('Debug - Geofence check error: $e');
      return {'isValid': false, 'isPending': true};
    }
  }

  // Add new method for location pending dialog
  Future<bool> _showLocationPendingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Pending'),
          ],
        ),
        content: const Text(
          'Unable to verify your exact location. Would you like to proceed with check-in anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
    return result ?? false;
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
          // Show user-friendly message with action
          Get.snackbar(
            'Location Access Required',
            'Please enable location access in your device settings to check in.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () => openAppSettings(),
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
          return;
        }
      }

      // 2. Check services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show user-friendly message with action
        Get.snackbar(
          'Location Services',
          'Please turn on location services to check in.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      // 3. Get position without time limit
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;

      // Only validate if coordinates are exactly 0,0
      if (position.latitude == 0 && position.longitude == 0) {
        setState(() {
          _currentAddress = 'Waiting for location...';
        });
        return;
      }

      setState(() {
        _currentPosition = position;
      });

      // 5. Get address and check geofence
      await _getAddressFromLatLng(position.latitude, position.longitude);
      await _checkGeofenceWithPending();
    } catch (e) {
      print('Debug - Error getting position: $e');
      if (!mounted) return;
      setState(() {
        _currentAddress = 'Waiting for location...';
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
    _positionStreamSubscription?.cancel();

    if (widget.journeyPlan.isPending) {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          if (mounted && widget.journeyPlan.isPending) {
            setState(() {
              _currentPosition = position;
            });
            _checkGeofenceWithPending();
          }
        },
        onError: (error) {
          print('Error in location stream: $error');
          // Don't show error to user for stream errors
          // Just log it and continue
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
        'Location Update',
        'Please wait while we get your current location...',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
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
        'Location updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      await _refreshJourneyStatus();
    } catch (e) {
      print('Error updating client location: $e');
      Get.snackbar(
        'Update Failed',
        'Could not update location. Please try again.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
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
                                    if (!widget.journeyPlan.isInTransit) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isWithinGeofence
                                              ? Colors.green.withOpacity(0.1)
                                              : _isLocationPending
                                                  ? Colors.orange
                                                      .withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isWithinGeofence
                                                  ? Icons.check_circle
                                                  : _isLocationPending
                                                      ? Icons.location_off
                                                      : Icons.warning,
                                              size: 12,
                                              color: _isWithinGeofence
                                                  ? Colors.green
                                                  : _isLocationPending
                                                      ? Colors.orange
                                                      : Colors.red,
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                _isWithinGeofence
                                                    ? 'Within range'
                                                    : _isLocationPending
                                                        ? 'Location pending'
                                                        : 'Outside range',
                                                style: TextStyle(
                                                  color: _isWithinGeofence
                                                      ? Colors.green
                                                      : _isLocationPending
                                                          ? Colors.orange
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
                                          padding:
                                              const EdgeInsets.only(top: 3),
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
    // Show check-in time and duration if journey is in progress
    if (label == 'Check-in Location' && widget.journeyPlan.isInTransit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.access_time,
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
                  'Check-in Time',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.journeyPlan.checkInTime != null
                      ? DateFormat('h:mm a')
                          .format(widget.journeyPlan.checkInTime!)
                      : 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.2,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _getDurationSinceCheckIn(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.2,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Skip rendering check-in location if journey is in progress
    if (label == 'Check-in Location' && widget.journeyPlan.isInTransit) {
      return const SizedBox.shrink();
    }

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

  // Add back the _calculateDistance method
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

    return earthRadius * c;
  }

  // Optimize submit check-in for parallel execution
  Future<void> _submitCheckIn() async {
    try {
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

      // Start all operations in parallel
      final results = await Future.wait([
        // Upload image
        ApiService.uploadImage(_capturedImage!),
        // Get current position if not cached
        _currentPosition == null
            ? Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
              )
            : Future.value(_currentPosition),
      ], eagerError: false);

      final imageUrl = results[0] as String;
      final position = results[1] as Position?;

      if (widget.journeyPlan.id == null) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Journey ID is required to check in.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return;
      }

      // Update journey plan statuses in parallel
      final statusUpdates = await Future.wait([
        // Update to checked-in status
        ApiService.updateJourneyPlan(
          journeyId: widget.journeyPlan.id!,
          clientId: widget.journeyPlan.client.id,
          status: JourneyPlan.statusCheckedIn,
          checkInTime: DateTime.now(),
          latitude: position?.latitude,
          longitude: position?.longitude,
          imageUrl: imageUrl,
        ),
        // Update to in-progress status
        ApiService.updateJourneyPlan(
          journeyId: widget.journeyPlan.id!,
          clientId: widget.journeyPlan.client.id,
          status: JourneyPlan.statusInProgress,
        ),
      ], eagerError: false);

      final inProgressPlan = statusUpdates[1] as JourneyPlan;

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (widget.onCheckInSuccess != null && mounted) {
        widget.onCheckInSuccess!(inProgressPlan);
      }

      // Show quick success message
      Get.snackbar(
        'Success',
        'Check-in successful!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
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
        Get.snackbar(
          'Error',
          'Failed to check in. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
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

  // Add this new method to calculate duration
  String _getDurationSinceCheckIn() {
    if (widget.journeyPlan.checkInTime == null) return 'N/A';

    final now = DateTime.now();
    final checkInTime = widget.journeyPlan.checkInTime!;
    final difference = now.difference(checkInTime);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}
