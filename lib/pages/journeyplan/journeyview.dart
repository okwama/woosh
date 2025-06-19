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

    // Clean up any image picker resources
    ImageCache().clear();
    ImageCache().clearLiveImages();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Clean up camera resources when app goes to background
      ImageCache().clear();
      ImageCache().clearLiveImages();
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

  Future<void> _submitSimplifiedCheckIn(File imageFile) async {
    try {
      print('🔄 Starting simplified check-in submission...');

      // Show loading indicator
      print('⌛ Showing loading indicator...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload image
      print('📤 Uploading image...');
      print('📦 Image file size: ${await imageFile.length()} bytes');
      print('📦 Image file path: ${imageFile.path}');

      final imageUrl = await ApiService.uploadImage(
        imageFile,
        maxWidth: 800,
        quality: 60,
      );
      print('✅ Image uploaded successfully');
      print('🔗 Image URL: $imageUrl');

      // Update journey plan
      print('📝 Updating journey plan...');
      print(
          '📍 Location data: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      final updatedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusInProgress,
        imageUrl: imageUrl,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      print('✅ Journey plan updated successfully');
      print('📊 New status: ${updatedPlan.statusText}');

      // Dismiss loading indicator
      if (mounted && Navigator.canPop(context)) {
        print('⌛ Dismissing loading indicator...');
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        print('✅ Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in successful'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Update parent
      if (widget.onCheckInSuccess != null) {
        print('📢 Notifying parent of success...');
        widget.onCheckInSuccess!(updatedPlan);
      }

      // Navigate to reports
      if (mounted) {
        print('🔄 Navigating to reports page...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportsOrdersPage(
              journeyPlan: updatedPlan,
              onAllReportsSubmitted: _handleAllReportsSubmitted,
            ),
          ),
        );
      }
      print('✅ Check-in process completed successfully');
    } catch (e) {
      print('❌ Error during check-in submission:');
      print('Error details: $e');
      print('Stack trace: ${StackTrace.current}');

      if (mounted) {
        // Dismiss loading indicator
        if (Navigator.canPop(context)) {
          print('⌛ Dismissing error loading indicator...');
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit check-in: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw e;
    }
  }

  Future<void> _checkIn() async {
    try {
      print('🔵 Starting check-in process...');
      setState(() {
        _isCheckingIn = true;
      });

      // 1. Check for active visits
      print('🔍 Checking for active visits...');
      final activeVisit = await ApiService.getActiveVisit();
      if (activeVisit != null) {
        print('⚠️ Found active visit: ${activeVisit.id}');
      }

      // 2. Validation checks
      if (widget.journeyPlan.status == JourneyPlan.statusInProgress) {
        print('⚠️ Already checked in to this visit');
        Get.snackbar(
            'Already Checked In', 'You are already checked in to this visit.');
        return;
      }

      if (activeVisit != null && activeVisit.id != widget.journeyPlan.id) {
        print('⚠️ Another visit is active: ${activeVisit.id}');
        Get.snackbar(
            'Active Visit', 'Please complete your current visit first.');
        return;
      }

      // 3. Get location if needed
      if (_currentPosition == null) {
        print('📍 Getting current position...');
        await _getCurrentPosition();
        if (_currentPosition == null) {
          print('❌ Failed to get location');
          throw Exception('Could not get current location');
        }
        print(
            '📍 Position obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }

      // 4. Take photo
      print('📸 Opening camera...');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 60,
      );

      if (image == null) {
        print('❌ No image captured');
        return;
      }
      print('📸 Image captured: ${image.path}');

      // 5. Submit check-in
      print('📤 Submitting check-in...');
      await _submitSimplifiedCheckIn(File(image.path));
    } catch (e) {
      print('❌ Check-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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

  // Simplified check-out handler
  Future<void> _handleAllReportsSubmitted() async {
    if (!mounted || widget.journeyPlan.id == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completing visit...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 1. Quick validation
      if (widget.journeyPlan.status != JourneyPlan.statusInProgress) {
        throw Exception('Journey must be in progress to complete');
      }

      // 2. Submit completion with minimal data
      final completedPlan = await ApiService.updateJourneyPlan(
        journeyId: widget.journeyPlan.id!,
        clientId: widget.journeyPlan.client.id,
        status: JourneyPlan.statusCompleted,
      );

      // 3. Show quick success message and update UI
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Visit completed successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Update parent if needed
        if (widget.onCheckInSuccess != null) {
          widget.onCheckInSuccess!(completedPlan);
        }

        // Navigate back or to next screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not complete visit: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleAllReportsSubmitted,
            ),
          ),
        );
      }
    }
  }

  // Helper method to validate completion requirements
  bool _canCompleteJourney() {
    return widget.journeyPlan.id != null &&
        widget.journeyPlan.status == JourneyPlan.statusInProgress;
  }

  // Method to handle manual completion if needed
  Future<void> _completeJourney() async {
    if (!_canCompleteJourney()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot complete visit at this time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _handleAllReportsSubmitted();
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
                                            widget.journeyPlan.status ==
                                                    JourneyPlan.statusInProgress
                                                ? Icons.check_circle
                                                : _isWithinGeofence
                                                    ? Icons.check_circle
                                                    : Icons.warning,
                                            size: 12,
                                            color: widget.journeyPlan.status ==
                                                    JourneyPlan.statusInProgress
                                                ? Colors.blue
                                                : _isWithinGeofence
                                                    ? Colors.green
                                                    : Colors.red,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              widget.journeyPlan.status ==
                                                      JourneyPlan
                                                          .statusInProgress
                                                  ? 'Checked In'
                                                  : _isWithinGeofence
                                                      ? 'Within range'
                                                      : 'Outside range',
                                              style: TextStyle(
                                                color: widget.journeyPlan
                                                            .status ==
                                                        JourneyPlan
                                                            .statusInProgress
                                                    ? Colors.blue
                                                    : _isWithinGeofence
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
                                    // Only show distance if not checked in
                                    if (!_isWithinGeofence &&
                                        widget.journeyPlan.status !=
                                            JourneyPlan.statusInProgress)
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
    // Don't show location info if already checked in
    if (label == 'Current Location' &&
        (widget.journeyPlan.status == JourneyPlan.statusInProgress ||
            widget.journeyPlan.status == JourneyPlan.statusCompleted)) {
      return const SizedBox.shrink(); // Hide location info after check-in
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
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
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

  // Stop location tracking after check-in
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    setState(() {
      _isFetchingLocation = false;
    });
  }

  // Modify check-in success handler
  void _onCheckInSuccess() {
    _stopLocationTracking();
    setState(() {
      _isCheckingIn = false;
    });
  }
}
