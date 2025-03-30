import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/pages/journeyplan/reports/reportMain_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:whoosh/services/universal_file.dart';

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
  bool _isCheckingIn = false;
  bool _isFetchingLocation = false;
  bool _isWithinGeofence = false;
  double _distanceToOutlet = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Notes-related variables
  final TextEditingController _notesController = TextEditingController();
  bool _isEditingNotes = false;
  bool _isSavingNotes = false;

  // Camera-related variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraVisible = false;

  // Geofencing constants
  static const double GEOFENCE_RADIUS_METERS =
      100000.0; // Increased to 100 meters
  static const Duration LOCATION_UPDATE_INTERVAL = Duration(seconds: 5);

  String _currentAddress = 'Fetching location...';

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

    _initializeCamera();

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

    // Cancel camera controller
    _cameraController?.dispose();
    _cameraController = null;

    // Dispose of text controller
    _notesController.dispose();

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

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

  @override
  void didUpdateWidget(JourneyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If journey plan status changes to checked in, stop location updates
    if (!oldWidget.journeyPlan.isCheckedIn && widget.journeyPlan.isCheckedIn) {
      _positionStreamSubscription?.cancel();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        throw Exception('No cameras available');
      }
    } catch (e) {
      print('Failed to initialize camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize camera: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showCameraDialog() async {
    if (!_isCameraInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Camera is not ready. Please try again.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCameraVisible = true;
      });
    }

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
                        if (mounted) {
                          setState(() {
                            _isCameraVisible = false;
                          });
                          Navigator.pop(context);

                          // Create platform-specific file
                          dynamic imageFile = kIsWeb ? image : File(image.path);
                          await _processImage(imageFile);
                        }
                      } catch (e) {
                        print('Error capturing image: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to capture image: $e')),
                          );
                        }
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

  Future<dynamic> _captureImage() async {
    try {
      if (kIsWeb) {
        // For web platforms, use ImagePicker with camera source only
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera, // Explicitly use camera only
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image == null) {
          throw Exception(
              'No image was captured. Camera access may have been denied.');
        }

        // Return the XFile directly for web
        return image;
      } else {
        // For mobile platforms, use camera controller directly
        if (!_isCameraInitialized || _cameraController == null) {
          // Try to initialize the camera if not already initialized
          await _initializeCamera();

          if (!_isCameraInitialized || _cameraController == null) {
            throw Exception(
                'Camera could not be initialized. Please check camera permissions.');
          }
        }

        final image = await _cameraController!.takePicture();
        return File(image.path);
      }
    } catch (e) {
      print('Error capturing image: $e');
      // Show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _processImage(dynamic imageFile) async {
    if (mounted) {
      setState(() {
        _isCheckingIn = true;
      });
    }

    try {
      print('Uploading image...');
      final imageUrl = await ApiService.uploadImage(imageFile);
      print('Image uploaded successfully: $imageUrl');

      if (widget.journeyPlan.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Journey ID is required to check in.')),
          );
        }
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

      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
        status: JourneyPlan.statusCheckedIn,
        checkInTime: DateTime.now(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        imageUrl: imageUrl,
      );

      // Immediately update to In Progress status
      final inProgressPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
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
              Text('Outlet: ${inProgressPlan.outlet.name}'),
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
          SnackBar(content: Text('Error checking in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
          _isCameraVisible = false;
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

      // Get outlet coordinates from the journey plan
      final outletLat = widget.journeyPlan.outlet.latitude;
      final outletLon = widget.journeyPlan.outlet.longitude;

      // Add debug logging
      print('\nDebug - Current Position:');
      print('Latitude: ${_currentPosition!.latitude}');
      print('Longitude: ${_currentPosition!.longitude}');
      print('Debug - Outlet Position:');
      print('Latitude: $outletLat');
      print('Longitude: $outletLon');

      if (outletLat == null || outletLon == null) {
        print('Debug - Outlet coordinates not available');
        return false;
      }

      // Calculate distance to outlet
      _distanceToOutlet = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        outletLat,
        outletLon,
      );

      // Check if distance is within acceptable range
      final isWithinRange = _distanceToOutlet <= GEOFENCE_RADIUS_METERS;

      print(
          'Debug - Geofence status: ${isWithinRange ? "Within range" : "Outside range"}');
      print(
          'Distance to outlet: ${_distanceToOutlet.toStringAsFixed(2)} meters');

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
                  'Distance to outlet: ${_distanceToOutlet.toStringAsFixed(2)} meters\n');
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
              'You must be closer to the outlet to check in. Please move within ${(GEOFENCE_RADIUS_METERS / 1000).toStringAsFixed(0)} kilometers.',
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
              const SizedBox(height: 12),
              const Text(
                'A photo will be taken using your camera to verify your presence.',
                style: TextStyle(color: Colors.blue, fontSize: 13),
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

      // Show a message that camera is about to open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening camera for check-in photo...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Capture image - returns File on mobile, XFile on web
      final imageFile = await _captureImage();
      if (imageFile == null) {
        throw Exception('Failed to capture image');
      }

      // Upload image
      await _submitWithImage(imageFile);
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

  Future<void> _submitWithImage(dynamic imageFile) async {
    if (imageFile != null) {
      try {
        print('Uploading image...');
        final imageUrl = await ApiService.uploadImage(imageFile);
        print('Image uploaded successfully: $imageUrl');

        if (widget.journeyPlan.id == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Journey ID is required to check in.')),
            );
          }
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

        final updatedPlan = await ApiService.updateJourneyPlan(
          journeyId: widget.journeyPlan.id!,
          outletId: widget.journeyPlan.outlet.id,
          status: JourneyPlan.statusCheckedIn,
          checkInTime: DateTime.now(),
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          imageUrl: imageUrl,
        );

        // Immediately update to In Progress status
        final inProgressPlan = await ApiService.updateJourneyPlan(
          journeyId: widget.journeyPlan.id!,
          outletId: widget.journeyPlan.outlet.id,
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
                Text('Outlet: ${inProgressPlan.outlet.name}'),
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
            builder: (context) =>
                ReportsOrdersPage(journeyPlan: inProgressPlan),
          ),
        );
      } catch (e) {
        print('Error checking in: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking in: $e')),
          );
        }
      }
    }
  }

  // Handle completion when all reports are submitted
  Future<void> _handleAllReportsSubmitted() async {
    try {
      // Update journey status to completed
      final completedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        outletId: widget.journeyPlan.outlet.id,
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
        outletId: widget.journeyPlan.outlet.id,
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
      print('Outlet Latitude: ${widget.journeyPlan.outlet.latitude}');
      print('Outlet Longitude: ${widget.journeyPlan.outlet.longitude}');

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

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Check-In'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Status Card
            Card(
              margin: const EdgeInsets.only(bottom: 8.0),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: widget.journeyPlan.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.journeyPlan.statusColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.journeyPlan.statusText.toUpperCase(),
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
            ),
            // Journey Details Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8.0),
                        topRight: Radius.circular(8.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.journeyPlan.outlet.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12.0),
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
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    'Location',
                                    widget.journeyPlan.outlet.address,
                                    Icons.location_on,
                                  ),
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
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isWithinGeofence
                                                ? Icons.check_circle
                                                : Icons.warning,
                                            size: 14,
                                            color: _isWithinGeofence
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _isWithinGeofence
                                                  ? 'Within range'
                                                  : 'Outside range',
                                              style: TextStyle(
                                                color: _isWithinGeofence
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isWithinGeofence)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${_distanceToOutlet.toStringAsFixed(1)}m away',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
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
                        const SizedBox(height: 16),
                        _buildNotesSection(),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8.0),
                        bottomRight: Radius.circular(8.0),
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
                            icon: const Icon(Icons.assessment, size: 16),
                            label: const Text('View Reports'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          )
                        else if (widget.journeyPlan.isPending)
                          ElevatedButton.icon(
                            onPressed: (_isCheckingIn || !_isWithinGeofence)
                                ? null
                                : _checkIn,
                            icon: const Icon(Icons.directions, size: 16),
                            label: const Text('Check In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
              const SizedBox(height: 2),
              if (_isFetchingLocation && label == 'Current Location')
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fetching location...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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
                    fontSize: 12,
                    height: 1.3,
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
            const Icon(Icons.notes, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Notes',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () {
                _showEditNotesDialog();
              },
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: widget.journeyPlan.notes?.isNotEmpty == true
              ? Text(widget.journeyPlan.notes!)
              : Text(
                  'No notes added',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
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
                  outletId: widget.journeyPlan.outletId,
                  notes: notesController.text.trim(),
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
