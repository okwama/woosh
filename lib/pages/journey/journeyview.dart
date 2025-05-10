import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/journeyplan_model.dart';

class JourneyView extends StatefulWidget {
  final JourneyPlan journeyPlan;

  const JourneyView({
    Key? key,
    required this.journeyPlan,
  }) : super(key: key);

  @override
  _JourneyViewState createState() => _JourneyViewState();
}

class _JourneyViewState extends State<JourneyView> {
  RxBool _isLocationUpdating = false.obs;
  RxBool _locationError = false.obs;
  RxString _locationErrorMessage = ''.obs;

  Future<void> _loadJourneyStatus() async {
    try {
      final client = await ApiService.getClient(widget.journeyPlan.clientId);
      if (client != null) {
        // Update the journey plan status
        setState(() {
          widget.journeyPlan.copyWith(
            latitude: client.latitude,
            longitude: client.longitude,
          );
        });
      }
    } catch (e) {
      print('Error loading journey status: $e');
    }
  }

  Future<void> _updateClientLocation() async {
    if (_isLocationUpdating.value) return;

    try {
      _isLocationUpdating.value = true;
      _locationError.value = false;
      _locationErrorMessage.value = '';

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError.value = true;
        _locationErrorMessage.value =
            'Location services are disabled. Please enable location services to update your location.';
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationError.value = true;
          _locationErrorMessage.value =
              'Location permission denied. Please enable location permission to update your location.';
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationError.value = true;
        _locationErrorMessage.value =
            'Location permission permanently denied. Please enable location permission in settings.';
        return;
      }

      // Get current position with timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        _locationError.value = true;
        _locationErrorMessage.value =
            'Location request timed out. Please try again.';
        return;
      }

      if (position == null) {
        _locationError.value = true;
        _locationErrorMessage.value =
            'Unable to get current location. Please try again.';
        return;
      }

      // Update location in the database
      try {
        final client = await ApiService.updateClientLocation(
          clientId: widget.journeyPlan.clientId,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        Get.snackbar(
          'Success',
          'Location updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        _loadJourneyStatus(); // Refresh journey status
      } catch (e) {
        _locationError.value = true;
        _locationErrorMessage.value = e.toString();
      }
    } catch (e) {
      _locationError.value = true;
      _locationErrorMessage.value =
          'An error occurred while updating location. Please try again.';
      print('Error updating location: $e');
    } finally {
      _isLocationUpdating.value = false;
    }
  }

  Widget _buildUpdateLocationButton() {
    return Obx(() {
      if (_isLocationUpdating.value) {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          label: const Text('Updating Location...'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.blue.withOpacity(0.7),
          ),
        );
      }

      if (_locationError.value) {
        return Column(
          children: [
            Text(
              _locationErrorMessage.value,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _updateClientLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      }

      return ElevatedButton.icon(
        onPressed: _updateClientLocation,
        icon: const Icon(Icons.location_on),
        label: const Text('Update Location'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUpdateLocationButton(),
            // Add other journey details widgets here
          ],
        ),
      ),
    );
  }
}
