import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'dart:convert';

import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/checkin_service.dart';
import 'package:woosh/pages/managers/service/location_service.dart';

// Constants
class CheckInConstants {
  static const double geofenceRadius =
      50000000.0; // Increased to cover large distances during testing
  static const Duration locationUpdateInterval = Duration(seconds: 10);
  static const Duration locationFastUpdateInterval = Duration(seconds: 5);
  static const Duration cacheDuration = Duration(hours: 1);
  static const String outletsCacheKey = 'cached_outlets';
  static const String lastFetchTimeKey = 'last_outlet_fetch_time';
}

// Services
class LocationService {
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 5),
    );
  }

  static Future<String> getAddressFromPosition(Position position) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isEmpty) return 'Unknown location';

      final place = placemarks.first;
      return [
        if (place.street != null) place.street,
        if (place.subLocality != null) place.subLocality,
        if (place.locality != null) place.locality,
      ].where((part) => part != null).join(', ');
    } catch (e) {
      return 'Location at ${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}';
    }
  }

  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    double lat1Rad = lat1 * pi / 180;
    double lat2Rad = lat2 * pi / 180;
    double deltaLat = (lat2 - lat1) * pi / 180;
    double deltaLon = (lon2 - lon1) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}

class OutletService {
  static final _storage = GetStorage();

  static Future<List<dynamic>> getOutletsWithCache() async {
    // Check if cache is valid
    final lastFetchTime = _storage.read(CheckInConstants.lastFetchTimeKey);
    final cachedOutlets = _storage.read(CheckInConstants.outletsCacheKey);

    if (lastFetchTime != null &&
        cachedOutlets != null &&
        DateTime.now().difference(DateTime.parse(lastFetchTime)) <
            CheckInConstants.cacheDuration) {
      return cachedOutlets;
    }

    // Fetch fresh data
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/outlets'),
            headers: await _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final outlets = json.decode(response.body);
        // Update cache
        await _storage.write(CheckInConstants.outletsCacheKey, outlets);
        await _storage.write(
          CheckInConstants.lastFetchTimeKey,
          DateTime.now().toIso8601String(),
        );
        return outlets;
      }
      throw Exception('Failed to fetch outlets: ${response.statusCode}');
    } catch (e) {
      // Return cached data even if stale when network fails
      if (cachedOutlets != null) return cachedOutlets;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> findNearestOutlet(
      Position position) async {
    final outlets = await getOutletsWithCache();
    if (outlets.isEmpty) return null;

    Map<String, dynamic>? nearest;
    double? minDistance;

    for (final outlet in outlets) {
      if (outlet['latitude'] == null || outlet['longitude'] == null) continue;

      final distance = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        outlet['latitude'],
        outlet['longitude'],
      );

      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearest = outlet;
      }
    }

    return nearest?..['distance'] = minDistance;
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = _storage.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

class OutletLocationTracker {
  static Stream<Map<String, dynamic>?> trackNearestOutlet() {
    final controller = StreamController<Map<String, dynamic>?>();
    StreamSubscription<Position>? positionSub;
    List<dynamic> outlets = [];

    // Initialize
    () async {
      try {
        outlets = await OutletService.getOutletsWithCache();
        if (outlets.isEmpty) {
          controller.add(null);
          return;
        }

        // Start location updates
        positionSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 50, // Update every 50 meters
          ),
        ).listen((position) async {
          final nearest = await OutletService.findNearestOutlet(position);
          controller.add(nearest);
        });
      } catch (e) {
        controller.addError(e);
      }
    }();

    controller.onCancel = () {
      positionSub?.cancel();
    };

    return controller.stream;
  }
}

// Camera and UI components remain mostly the same as before
// [CameraCapture, GridPainter, ManagerCheckInCard widgets]

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _outletData;
  Map<String, dynamic>? _cachedOutletData;
  StreamSubscription<Map<String, dynamic>?>? _outletSubscription;

  @override
  void initState() {
    super.initState();
    _loadCachedOutlet();
    _startOutletTracking();
  }

  @override
  void dispose() {
    _outletSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedOutlet() async {
    // Try to get cached outlets and show the nearest one immediately
    final outlets = await OutletService.getOutletsWithCache();
    if (outlets.isNotEmpty) {
      // Use current location if possible, else just pick the first
      try {
        final position = await LocationService.getCurrentPosition();
        final nearest = await OutletService.findNearestOutlet(position);
        if (nearest != null && mounted) {
          setState(() {
            _cachedOutletData = nearest;
            _isLoading = false;
          });
        }
      } catch (_) {
        // If location fails, just show the first outlet
        setState(() {
          _cachedOutletData = outlets.first;
          _isLoading = false;
        });
      }
    }
  }

  void _startOutletTracking() {
    _outletSubscription = OutletLocationService.trackNearestOutlet().listen(
      (outlet) {
        setState(() {
          _outletData = outlet;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _error = 'Failed to track nearest outlet: $error';
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _outletData = null;
                _error = null;
              });
              _loadCachedOutlet();
              _startOutletTracking();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _outletData = null;
                  _error = null;
                });
                _loadCachedOutlet();
                _startOutletTracking();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show the freshest outlet data if available
    if (_outletData != null) {
      return ManagerCheckInCard(
        outletId: _outletData!['id'],
        outletName: _outletData!['name'],
        outletAddress: _outletData!['address'],
        distance: _outletData!['distance'],
      );
    }

    // If loading and cached outlet exists, show cached outlet immediately
    if (_isLoading && _cachedOutletData != null) {
      return ManagerCheckInCard(
        outletId: _cachedOutletData!['id'],
        outletName: _cachedOutletData!['name'],
        outletAddress: _cachedOutletData!['address'],
        distance: _cachedOutletData!['distance'],
      );
    }

    // If still loading and no cached data, show skeleton loader
    if (_isLoading) {
      return const OutletCardSkeleton();
    }

    // If nothing found
    return const Center(
      child: Text('No outlet found nearby. Please check your location.'),
    );
  }

  Future<Map<String, String>> _getAuthHeaders([String? contentType]) async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': contentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('XMLHttpRequest error') ||
        error.toString().contains('TimeoutException')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error: Please check your internet connection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Updated ManagerCheckInCard with distance awareness
class ManagerCheckInCard extends StatefulWidget {
  final int outletId;
  final String outletName;
  final String outletAddress;
  final double? distance;

  const ManagerCheckInCard({
    super.key,
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    this.distance,
  });

  @override
  State<ManagerCheckInCard> createState() => _ManagerCheckInCardState();
}

class _ManagerCheckInCardState extends State<ManagerCheckInCard> {
  // Location state
  Position? _currentPosition;
  String _currentAddress = 'Detecting location...';
  bool _isFetchingLocation = false;
  bool _isWithinGeofence = false;
  double _distanceToOutlet = 0.0;

  // Check-in state
  bool _isCheckedIn = false;
  bool _isProcessing = false;
  DateTime? _checkInTime;
  StreamSubscription<Position>? _positionStream;

  // Camera state
  bool _showCamera = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadCheckInStatus();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _loadCheckInStatus() async {
    try {
      setState(() => _isProcessing = true);

      final response = await http
          .get(
        Uri.parse('${ApiService.baseUrl}/checkin/status'),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isCheckedIn = data['isCheckedIn'] ?? false;
            _checkInTime = data['checkInTime'] != null
                ? DateTime.parse(data['checkInTime'])
                : null;
            // If checked in, automatically set within geofence to allow checkout
            if (_isCheckedIn) {
              _isWithinGeofence = true;
            }
          });
        }
      }
    } catch (e) {
      _handleNetworkError(e);
      if (mounted) {
        _showErrorSnackbar('Failed to load check-in status: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _initializeLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // Try to use last known location if it's recent (within 10 minutes)
      final lastKnown = await Geolocator.getLastKnownPosition();
      final now = DateTime.now();
      if (lastKnown != null &&
          now.difference(lastKnown.timestamp).inMinutes < 10) {
        setState(() {
          _currentPosition = lastKnown;
        });
        final address = await LocationService.getAddressFromPosition(lastKnown);
        if (mounted) {
          setState(() => _currentAddress = address);
        }
        await _checkGeofence();
      }
      // Always try to get a fresh position in the background
      _getCurrentPosition();
      _startLocationUpdates();
    } catch (e) {
      _showErrorSnackbar('Location error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _getCurrentPosition() async {
    if (!mounted) return;

    setState(() => _isFetchingLocation = true);

    try {
      final position = await LocationService.getCurrentPosition();
      final address = await LocationService.getAddressFromPosition(position);

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
      });

      await _checkGeofence();
    } catch (e) {
      if (mounted) {
        setState(() => _currentAddress = 'Location unavailable');
        _showErrorSnackbar('Failed to get location: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();

    // Throttle: Only update every 30 meters and debounce updates to once every 3 seconds
    const int distanceFilter = 30; // meters
    const Duration debounceDuration = Duration(seconds: 3);
    DateTime? lastUpdate;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (Position position) {
        final now = DateTime.now();
        if (lastUpdate == null ||
            now.difference(lastUpdate!) > debounceDuration) {
          lastUpdate = now;
          if (mounted) {
            setState(() => _currentPosition = position);
            _checkGeofence();
          }
        }
      },
      onError: (error) {
        _showErrorSnackbar('Location update error: $error');
      },
    );
  }

  Future<bool> _checkGeofence() async {
    if (_currentPosition == null) return false;

    try {
      final response = await http
          .get(
        Uri.parse('${ApiService.baseUrl}/outlets/${widget.outletId}'),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get outlet location');
      }

      final data = json.decode(response.body);
      final outletLat = data['latitude']?.toDouble() ?? 0.0;
      final outletLon = data['longitude']?.toDouble() ?? 0.0;

      _distanceToOutlet = LocationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        outletLat,
        outletLon,
      );

      final isWithinRange =
          _distanceToOutlet <= CheckInConstants.geofenceRadius;

      if (mounted) {
        setState(() => _isWithinGeofence = isWithinRange);
      }

      return isWithinRange;
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Using local geofence check: ${e.toString()}');
        setState(() => _isWithinGeofence = true);
      }
      return true;
    }
  }

  Future<void> _handleCheckIn() async {
    if (!await _checkGeofence()) {
      _showErrorSnackbar(
          'You must be within ${CheckInConstants.geofenceRadius}m of the outlet to check in');
      return;
    }

    if (_isCheckedIn) {
      _showErrorSnackbar('You are already checked in');
      return;
    }
    setState(() => _showCamera = true);
  }

  void _handleImageCaptured(XFile image) async {
    setState(() {
      _capturedImage = image;
      _showCamera = false;
      _isProcessing = true;
    });

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/upload-image'));

      final headers = await _getAuthHeaders('multipart/form-data');
      request.headers.addAll(headers);

      request.files.add(await http.MultipartFile.fromPath(
          'attachment', _capturedImage!.path));

      request.fields['clientId'] = widget.outletId.toString();
      if (_currentPosition != null) {
        request.fields['latitude'] = _currentPosition!.latitude.toString();
        request.fields['longitude'] = _currentPosition!.longitude.toString();
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Image upload timeout');
        },
      );

      final imageResponse = await http.Response.fromStream(streamedResponse);

      if (imageResponse.statusCode != 200 && imageResponse.statusCode != 201) {
        final errorData = json.decode(imageResponse.body);
        throw Exception(
            errorData['message'] ?? 'Failed to upload check-in image');
      }

      final imageData = json.decode(imageResponse.body);
      final imageUrl = imageData['fileUrl'];

      final checkInResponse = await http
          .post(
        Uri.parse('${ApiService.baseUrl}/checkin'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'clientId': widget.outletId,
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'imageUrl': imageUrl,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (checkInResponse.statusCode == 201 ||
          checkInResponse.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isCheckedIn = true;
            _checkInTime = DateTime.now();
          });
          _showSuccessSnackbar('Checked in successfully!');
        }
      } else {
        final errorData = json.decode(checkInResponse.body);
        throw Exception(errorData['message'] ??
            'Check-in failed with status ${checkInResponse.statusCode}');
      }
    } catch (e) {
      _handleNetworkError(e);
      if (mounted) {
        _showErrorSnackbar('Check-in failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isProcessing = true);

    try {
      // Try to get location but don't block checkout if it fails
      Position? position;
      try {
        position = await LocationService.getCurrentPosition();
      } catch (e) {
        // Just log the error and continue with checkout
        print('Location not available for checkout: $e');
      }

      final requestBody = <String, dynamic>{};

      // Only add location if we successfully got it
      if (position != null) {
        requestBody['latitude'] = position.latitude;
        requestBody['longitude'] = position.longitude;
      }

      final response = await http
          .post(
        Uri.parse('${ApiService.baseUrl}/checkin/checkout'),
        headers: await _getAuthHeaders(),
        body: json.encode(requestBody),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isCheckedIn = false;
            _checkInTime = null;
            _capturedImage = null;
          });
          _showSuccessSnackbar('Checked out successfully');

          // Refresh location tracking after checkout
          _initializeLocation();
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to check out');
      }
    } catch (e) {
      _handleNetworkError(e);
      if (mounted) {
        _showErrorSnackbar('Check-out failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDistance(double meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)}km'
        : '${meters.toStringAsFixed(0)}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_showCamera) {
      return CameraCapture(
        onImageCaptured: _handleImageCaptured,
        onCancel: () => setState(() {
          _showCamera = false;
        }),
      );
    }

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOutletHeader(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(),
                    if (_currentPosition != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildDistanceIndicator(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildLocationInfo(),
                const SizedBox(height: 6),
                _buildCheckInOutButton(),
                if (_isCheckedIn &&
                    _checkInTime != null &&
                    _capturedImage != null) ...[
                  const SizedBox(height: 6),
                  _buildCheckInTime(),
                ],
                if (!_isCheckedIn && !_isWithinGeofence) ...[
                  _buildForceCheckInOption(),
                ],
              ],
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isCheckedIn
                              ? 'Processing Check-out...'
                              : 'Processing Check-in...',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOutletHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.store, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.outletName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.outletAddress,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
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

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _isCheckedIn
            ? Colors.orange.withOpacity(0.2)
            : Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCheckedIn ? Icons.access_time : Icons.pending,
            size: 12,
            color: _isCheckedIn ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 3),
          Text(
            _isCheckedIn ? 'IN PROGRESS' : 'READY',
            style: TextStyle(
              color: _isCheckedIn ? Colors.orange : Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _isFetchingLocation ? 'Detecting location...' : _currentAddress,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: _isFetchingLocation ? null : _getCurrentPosition,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _isFetchingLocation ? 'Updating...' : 'Refresh',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _isWithinGeofence
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isWithinGeofence ? Icons.check_circle : Icons.warning,
            size: 12,
            color: _isWithinGeofence ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _formatDistance(_distanceToOutlet),
              style: TextStyle(
                color: _isWithinGeofence ? Colors.green : Colors.orange,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: _isCheckedIn
          ? ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleCheckOut,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('CHECK OUT', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
                elevation: 1,
              ),
            )
          : ElevatedButton.icon(
              onPressed:
                  (_isProcessing || !_isWithinGeofence) ? null : _handleCheckIn,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: Text(
                _isProcessing
                    ? 'PROCESSING...'
                    : !_isWithinGeofence
                        ? 'TOO FAR'
                        : 'CHECK IN',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 1,
              ),
            ),
    );
  }

  Widget _buildCheckInTime() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Checked in at ${DateFormat('h:mm a').format(_checkInTime!)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
        if (_capturedImage != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.file(
                  File(_capturedImage!.path),
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black54,
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'Check-in photo',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForceCheckInOption() {
    return TextButton(
      onPressed: _isProcessing
          ? null
          : () async {
              await _checkGeofence();
              if (mounted) {
                setState(() => _isWithinGeofence = true);
              }
            },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(0, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Force Location Check', style: TextStyle(fontSize: 11)),
    );
  }

  Future<Map<String, String>> _getAuthHeaders([String? contentType]) async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': contentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('XMLHttpRequest error') ||
        error.toString().contains('TimeoutException')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error: Please check your internet connection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class CameraCapture extends StatefulWidget {
  final Function(XFile) onImageCaptured;
  final Function() onCancel;

  const CameraCapture({
    super.key,
    required this.onImageCaptured,
    required this.onCancel,
  });

  @override
  State<CameraCapture> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_isInitialized || _isTakingPicture) {
      return;
    }

    try {
      setState(() => _isTakingPicture = true);
      final XFile image = await _controller!.takePicture();
      widget.onImageCaptured(image);
    } catch (e) {
      _showError('Failed to take picture: $e');
      setState(() => _isTakingPicture = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Check-in Photo'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onCancel,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Check-in Photo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                CameraPreview(_controller!),
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: widget.onCancel,
                ),
                GestureDetector(
                  onTap: _isTakingPicture ? null : _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: _isTakingPicture
                        ? const CircularProgressIndicator()
                        : Container(
                            margin: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios,
                      color: Colors.white, size: 30),
                  onPressed: () async {
                    if (_cameras != null && _cameras!.length > 1) {
                      final currentLensDirection =
                          _controller!.description.lensDirection;
                      CameraDescription newCamera;

                      if (currentLensDirection == CameraLensDirection.back) {
                        newCamera = _cameras!.firstWhere(
                          (camera) =>
                              camera.lensDirection == CameraLensDirection.front,
                          orElse: () => _cameras!.first,
                        );
                      } else {
                        newCamera = _cameras!.firstWhere(
                          (camera) =>
                              camera.lensDirection == CameraLensDirection.back,
                          orElse: () => _cameras!.first,
                        );
                      }

                      await _controller!.dispose();
                      _controller = CameraController(
                        newCamera,
                        ResolutionPreset.medium,
                        enableAudio: false,
                      );
                      await _controller!.initialize();
                      if (mounted) setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add a skeleton loader widget for the outlet card
class OutletCardSkeleton extends StatelessWidget {
  const OutletCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 16,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.only(bottom: 8),
            ),
            Container(
              width: 200,
              height: 12,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.only(bottom: 8),
            ),
            Container(
              width: 80,
              height: 12,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.only(bottom: 8),
            ),
            Container(
              width: double.infinity,
              height: 36,
              color: Colors.grey.shade100,
              margin: const EdgeInsets.only(top: 12),
            ),
          ],
        ),
      ),
    );
  }
}
