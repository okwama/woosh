import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/clients/client_model.dart';

class EnhancedGeofencingService extends GetxService {
  static EnhancedGeofencingService get instance => Get.find<EnhancedGeofencingService>();

  final GetStorage _storage = GetStorage();
  Timer? _locationUpdateTimer;
  Position? _currentPosition;
  
  // Geofencing configuration
  static const double defaultGeofenceRadius = 100.0; // 100 meters
  static const double accuracyThreshold = 10.0; // 10 meters accuracy required
  static const int locationUpdateIntervalSeconds = 10; // Update every 10 seconds
  static const int maxLocationAttempts = 5;
  static const int locationTimeoutSeconds = 30;

  // Observable data
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxBool isLocationServiceActive = false.obs;
  final RxDouble currentAccuracy = 0.0.obs;
  final RxString locationStatus = 'Unknown'.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeLocationService();
  }

  @override
  void onClose() {
    _locationUpdateTimer?.cancel();
    super.onClose();
  }

  /// Initialize location service
  Future<void> _initializeLocationService() async {
    try {
      await _checkLocationPermissions();
      await _getCurrentLocation();
      _startLocationUpdates();
      
      print('✅ Enhanced geofencing service initialized');
    } catch (e) {
      print('❌ Failed to initialize geofencing service: $e');
      locationStatus.value = 'Error: ${e.toString()}';
    }
  }

  /// Check and request location permissions
  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      locationStatus.value = 'Location services disabled';
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        locationStatus.value = 'Location permission denied';
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      locationStatus.value = 'Location permission permanently denied';
      throw Exception('Location permissions are permanently denied');
    }

    isLocationServiceActive.value = true;
    locationStatus.value = 'Location service active';
  }

  /// Get current location with enhanced accuracy
  Future<Position> _getCurrentLocation() async {
    try {
      locationStatus.value = 'Getting location...';
      
      Position? bestPosition;
      double bestAccuracy = double.infinity;
      
      // Try multiple times to get the most accurate position
      for (int attempt = 1; attempt <= maxLocationAttempts; attempt++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: locationTimeoutSeconds),
          );
          
          print('📍 Location attempt $attempt: accuracy ${position.accuracy}m');
          
          if (position.accuracy < bestAccuracy) {
            bestPosition = position;
            bestAccuracy = position.accuracy;
          }
          
          // If we have good accuracy, use it
          if (position.accuracy <= accuracyThreshold) {
            bestPosition = position;
            break;
          }
          
          // Wait a bit before next attempt
          if (attempt < maxLocationAttempts) {
            await Future.delayed(Duration(seconds: 2));
          }
          
        } catch (e) {
          print('Location attempt $attempt failed: $e');
          if (attempt == maxLocationAttempts) {
            throw e;
          }
        }
      }
      
      if (bestPosition == null) {
        throw Exception('Failed to get location after $maxLocationAttempts attempts');
      }
      
      _currentPosition = bestPosition;
      currentPosition.value = bestPosition;
      currentAccuracy.value = bestPosition.accuracy;
      locationStatus.value = 'Location acquired (${bestPosition.accuracy.toStringAsFixed(1)}m accuracy)';
      
      return bestPosition;
      
    } catch (e) {
      locationStatus.value = 'Failed to get location';
      throw Exception('Failed to get current location: $e');
    }
  }

  /// Start continuous location updates
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: locationUpdateIntervalSeconds),
      (_) => _updateLocation(),
    );
  }

  /// Update location periodically
  Future<void> _updateLocation() async {
    try {
      await _getCurrentLocation();
    } catch (e) {
      print('Periodic location update failed: $e');
    }
  }

  /// Check if user is within geofence of a client
  Future<GeofenceResult> checkGeofence(Client client, {double? customRadius}) async {
    try {
      if (_currentPosition == null) {
        await _getCurrentLocation();
      }
      
      if (_currentPosition == null) {
        return GeofenceResult(
          isWithinGeofence: false,
          distance: double.infinity,
          accuracy: 0.0,
          error: 'Current location not available',
        );
      }

      if (client.latitude == null || client.longitude == null) {
        return GeofenceResult(
          isWithinGeofence: false,
          distance: double.infinity,
          accuracy: _currentPosition!.accuracy,
          error: 'Client location not available',
        );
      }

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        client.latitude!,
        client.longitude!,
      );

      final radius = customRadius ?? defaultGeofenceRadius;
      final isWithinGeofence = distance <= radius;
      
      // Consider accuracy in geofence calculation
      final effectiveRadius = radius + _currentPosition!.accuracy;
      final isWithinAccurateGeofence = distance <= effectiveRadius;

      print('📍 Geofence check: distance=${distance.toStringAsFixed(1)}m, radius=${radius}m, accuracy=${_currentPosition!.accuracy.toStringAsFixed(1)}m');

      return GeofenceResult(
        isWithinGeofence: isWithinAccurateGeofence,
        distance: distance,
        accuracy: _currentPosition!.accuracy,
        clientLatitude: client.latitude!,
        clientLongitude: client.longitude!,
        userLatitude: _currentPosition!.latitude,
        userLongitude: _currentPosition!.longitude,
        radiusUsed: effectiveRadius,
      );
      
    } catch (e) {
      print('Geofence check failed: $e');
      return GeofenceResult(
        isWithinGeofence: false,
        distance: double.infinity,
        accuracy: 0.0,
        error: e.toString(),
      );
    }
  }

  /// Get distance to client
  Future<double?> getDistanceToClient(Client client) async {
    try {
      if (_currentPosition == null) {
        await _getCurrentLocation();
      }
      
      if (_currentPosition == null || client.latitude == null || client.longitude == null) {
        return null;
      }

      return Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        client.latitude!,
        client.longitude!,
      );
    } catch (e) {
      print('Error calculating distance to client: $e');
      return null;
    }
  }

  /// Validate location accuracy
  bool isLocationAccurate() {
    return _currentPosition != null && 
           _currentPosition!.accuracy <= accuracyThreshold;
  }

  /// Get location quality assessment
  LocationQuality getLocationQuality() {
    if (_currentPosition == null) {
      return LocationQuality.unavailable;
    }

    final accuracy = _currentPosition!.accuracy;
    
    if (accuracy <= 5) {
      return LocationQuality.excellent;
    } else if (accuracy <= 10) {
      return LocationQuality.good;
    } else if (accuracy <= 20) {
      return LocationQuality.fair;
    } else {
      return LocationQuality.poor;
    }
  }

  /// Get address from coordinates
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.street}, ${placemark.locality}, ${placemark.country}';
      }
      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Force location refresh
  Future<bool> forceLocationRefresh() async {
    try {
      await _getCurrentLocation();
      return true;
    } catch (e) {
      print('Force location refresh failed: $e');
      return false;
    }
  }

  /// Get location status info
  Map<String, dynamic> getLocationStatusInfo() {
    return {
      'isActive': isLocationServiceActive.value,
      'currentPosition': _currentPosition?.toJson(),
      'accuracy': currentAccuracy.value,
      'status': locationStatus.value,
      'quality': getLocationQuality().toString(),
      'lastUpdate': _currentPosition?.timestamp?.toIso8601String(),
    };
  }

  /// Calculate route distance between multiple points
  double calculateRouteDistance(List<Position> positions) {
    if (positions.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    
    for (int i = 0; i < positions.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        positions[i].latitude,
        positions[i].longitude,
        positions[i + 1].latitude,
        positions[i + 1].longitude,
      );
    }
    
    return totalDistance;
  }

  /// Get nearby clients within radius
  Future<List<Client>> getNearbyClients(List<Client> allClients, {double? radius}) async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }
    
    if (_currentPosition == null) return [];
    
    final searchRadius = radius ?? defaultGeofenceRadius * 5; // 5x geofence radius for nearby search
    final nearbyClients = <Client>[];
    
    for (final client in allClients) {
      if (client.latitude != null && client.longitude != null) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          client.latitude!,
          client.longitude!,
        );
        
        if (distance <= searchRadius) {
          nearbyClients.add(client);
        }
      }
    }
    
    // Sort by distance
    nearbyClients.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distanceB = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distanceA.compareTo(distanceB);
    });
    
    return nearbyClients;
  }

  /// Validate client location coordinates
  bool validateClientLocation(Client client) {
    if (client.latitude == null || client.longitude == null) {
      return false;
    }
    
    // Check if coordinates are within valid ranges
    final lat = client.latitude!;
    final lng = client.longitude!;
    
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Get location debugging info
  Map<String, dynamic> getLocationDebugInfo() {
    return {
      'currentPosition': _currentPosition?.toJson(),
      'accuracy': _currentPosition?.accuracy,
      'timestamp': _currentPosition?.timestamp?.toIso8601String(),
      'isServiceActive': isLocationServiceActive.value,
      'locationQuality': getLocationQuality().toString(),
      'status': locationStatus.value,
      'lastUpdateAttempt': DateTime.now().toIso8601String(),
    };
  }
}

class GeofenceResult {
  final bool isWithinGeofence;
  final double distance;
  final double accuracy;
  final double? clientLatitude;
  final double? clientLongitude;
  final double? userLatitude;
  final double? userLongitude;
  final double? radiusUsed;
  final String? error;

  GeofenceResult({
    required this.isWithinGeofence,
    required this.distance,
    required this.accuracy,
    this.clientLatitude,
    this.clientLongitude,
    this.userLatitude,
    this.userLongitude,
    this.radiusUsed,
    this.error,
  });

  /// Get user-friendly status message
  String get statusMessage {
    if (error != null) {
      return 'Error: $error';
    }
    
    if (isWithinGeofence) {
      return 'You are within the client location (${distance.toStringAsFixed(1)}m away)';
    } else {
      return 'You are ${distance.toStringAsFixed(1)}m away from the client location';
    }
  }

  /// Get accuracy assessment
  String get accuracyAssessment {
    if (accuracy <= 5) {
      return 'Excellent GPS accuracy';
    } else if (accuracy <= 10) {
      return 'Good GPS accuracy';
    } else if (accuracy <= 20) {
      return 'Fair GPS accuracy';
    } else {
      return 'Poor GPS accuracy - results may be unreliable';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'isWithinGeofence': isWithinGeofence,
      'distance': distance,
      'accuracy': accuracy,
      'clientLatitude': clientLatitude,
      'clientLongitude': clientLongitude,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'radiusUsed': radiusUsed,
      'error': error,
      'statusMessage': statusMessage,
      'accuracyAssessment': accuracyAssessment,
    };
  }
}

enum LocationQuality {
  excellent,  // <= 5m accuracy
  good,       // <= 10m accuracy
  fair,       // <= 20m accuracy
  poor,       // > 20m accuracy
  unavailable, // No location available
}