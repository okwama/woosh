import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:woosh/services/api_service.dart';
import 'dart:convert';
import 'package:get_storage/get_storage.dart';

// Constants
class CheckInConstants {
  static const double geofenceRadius =
      50000000.0; // Increased to cover large distances during testing
  static const Duration locationUpdateInterval = Duration(seconds: 10);
  static const Duration locationFastUpdateInterval = Duration(seconds: 5);
  static const String qrCodePrefix = 'OFFICE_';
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

class QRScanner extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final Function() onClose;

  const QRScanner({
    super.key,
    required this.onQRCodeScanned,
    required this.onClose,
  });

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? scanResult;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Office QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: MediaQuery.of(context).size.width * 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Align the QR code within the frame to scan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanResult == null) {
        setState(() {
          scanResult = scanData.code;
        });
        widget.onQRCodeScanned(scanData.code!);
      }
    });
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

      // Start with the first back camera
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
                // Grid overlay
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
                    // Implement camera switching
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

// GridPainter for camera overlay
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

class ManagerCheckInCard extends StatefulWidget {
  final int officeId;
  final String officeName;
  final String officeAddress;

  const ManagerCheckInCard({
    super.key,
    required this.officeId,
    required this.officeName,
    required this.officeAddress,
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
  double _distanceToOffice = 0.0;

  // Check-in state
  bool _isCheckedIn = false;
  bool _isProcessing = false;
  DateTime? _checkInTime;
  StreamSubscription<Position>? _positionStream;

  // QR Scanner state
  bool _showQRScanner = false;
  String? _qrScanError;
  String? _scannedQRCode;

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

      // Call the API to get current check-in status
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

            // If there's an image URL in the response, we could display it
            // but for now we'll use the local captured image
          });
        }
      } else {
        // Default to not checked in if API fails
        if (mounted) {
          setState(() {
            _isCheckedIn = false;
            _checkInTime = null;
          });
        }
      }
    } catch (e) {
      _handleNetworkError(e);
      if (mounted) {
        _showErrorSnackbar('Failed to load check-in status: ${e.toString()}');
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
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
      await _getCurrentPosition();
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

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() => _currentPosition = position);
          _checkGeofence();
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
      // Get office location from API
      final response = await http
          .get(
        Uri.parse('${ApiService.baseUrl}/office/${widget.officeId}'),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get office location');
      }

      final data = json.decode(response.body);
      final officeLat = data['latitude']?.toDouble() ?? 0.0;
      final officeLon = data['longitude']?.toDouble() ?? 0.0;

      print('Office coordinates: Lat $officeLat, Lon $officeLon');
      print(
          'Current coordinates: Lat ${_currentPosition!.latitude}, Lon ${_currentPosition!.longitude}');

      _distanceToOffice = LocationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        officeLat,
        officeLon,
      );

      print(
          'Distance to office: $_distanceToOffice meters (Radius: ${CheckInConstants.geofenceRadius} meters)');

      final isWithinRange =
          _distanceToOffice <= CheckInConstants.geofenceRadius;

      if (mounted) {
        setState(() => _isWithinGeofence = isWithinRange);
      }

      return isWithinRange;
    } catch (e) {
      // Use fallback location verification if API fails
      if (mounted) {
        _showErrorSnackbar('Using local geofence check: ${e.toString()}');
      }

      // Enable geofence regardless of location during testing
      if (mounted) {
        setState(() => _isWithinGeofence = true);
        return true;
      }
      return true;
    }
  }

  Future<void> _handleCheckIn() async {
    if (!await _checkGeofence()) {
      _showErrorSnackbar(
          'You must be within ${CheckInConstants.geofenceRadius}m of the office to check in');
      return;
    }

    setState(() {
      _showQRScanner = true;
      _qrScanError = null;
    });
  }

  void _handleQRCodeScanned(String qrCode) async {
    try {
      // Verify QR code with API
      final verifyResponse = await http.post(
        Uri.parse('${ApiService.baseUrl}/checkin/verify-qr'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'qrCode': qrCode,
          'officeId': widget.officeId,
        }),
      );

      if (verifyResponse.statusCode != 200) {
        final errorData = json.decode(verifyResponse.body);
        setState(
            () => _qrScanError = errorData['message'] ?? 'Invalid QR code');
        return;
      }

      // QR code verified, proceed to camera
      setState(() {
        _scannedQRCode = qrCode;
        _showQRScanner = false;
        _showCamera = true;
      });
    } catch (e) {
      if (!mounted) return;

      // If the API verification fails, check locally
      if (!qrCode
          .startsWith('${CheckInConstants.qrCodePrefix}${widget.officeId}_')) {
        setState(() => _qrScanError = 'Invalid office QR code');
        return;
      }

      setState(() {
        _scannedQRCode = qrCode;
        _showQRScanner = false;
        _showCamera = true;
      });
    }
  }

  void _handleImageCaptured(XFile image) async {
    setState(() {
      _capturedImage = image;
      _showCamera = false;
      _isProcessing = true;
    });

    try {
      // Prepare multipart request for the image upload
      var request = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/upload-image'));

      // Set headers including authorization
      final headers = await _getAuthHeaders('multipart/form-data');
      request.headers.addAll(headers);

      // Add file and form fields
      request.files.add(await http.MultipartFile.fromPath(
          'attachment', _capturedImage!.path));

      // Add check-in data
      request.fields['officeId'] = widget.officeId.toString();
      if (_currentPosition != null) {
        request.fields['latitude'] = _currentPosition!.latitude.toString();
        request.fields['longitude'] = _currentPosition!.longitude.toString();
      }
      if (_scannedQRCode != null) {
        request.fields['qrCodeHash'] = _scannedQRCode!;
      }

      // Upload the image with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30), // Upload might take longer
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

      // Now perform the actual check-in with the image URL
      final checkInResponse = await http
          .post(
        Uri.parse('${ApiService.baseUrl}/checkin'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'officeId': widget.officeId,
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'qrCodeHash': _scannedQRCode,
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
        throw Exception(
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
      // Call the check-out API
      final response = await http
          .post(
        Uri.parse('${ApiService.baseUrl}/checkin/checkout'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'officeId': widget.officeId,
          'checkOutTime': DateTime.now().toIso8601String(),
        }),
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
            _scannedQRCode = null;
          });
          _showSuccessSnackbar('Checked out successfully');
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
    if (_showQRScanner) {
      return QRScanner(
        onQRCodeScanned: _handleQRCodeScanned,
        onClose: () => setState(() => _showQRScanner = false),
      );
    }

    if (_showCamera) {
      return CameraCapture(
        onImageCaptured: _handleImageCaptured,
        onCancel: () => setState(() {
          _showCamera = false;
          _scannedQRCode = null;
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
                _buildOfficeHeader(),
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

  Widget _buildOfficeHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.business, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.officeName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.officeAddress,
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
            ? Colors.green.withOpacity(0.2)
            : Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCheckedIn ? Icons.verified : Icons.pending,
            size: 12,
            color: _isCheckedIn ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 3),
          Text(
            _isCheckedIn ? 'ACTIVE' : 'READY',
            style: TextStyle(
              color: _isCheckedIn ? Colors.green : Colors.blue,
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
          child: Text(
            _isFetchingLocation ? 'Updating...' : 'Refresh',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              _formatDistance(_distanceToOffice),
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
                        : 'SCAN & PHOTO',
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

  // Helper method to get auth headers
  Future<Map<String, String>> _getAuthHeaders([String? contentType]) async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': contentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper method for handling network errors
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

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _officeData;

  @override
  void initState() {
    super.initState();
    _loadOfficeData();
  }

  Future<void> _loadOfficeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('📍 Fetching office data from API...');

      // Call the actual API endpoint
      final response = await http
          .get(
        Uri.parse('${ApiService.baseUrl}/office'),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      print('📍 Office API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('📍 Office API response: $responseBody');

        final List<dynamic> offices = json.decode(responseBody);
        print('📍 Found ${offices.length} offices');

        // For now, just use the first office if any exists
        if (offices.isNotEmpty) {
          final officeData = offices[0];
          print(
              '📍 Using office: ${officeData['name']}, ID: ${officeData['id']}');
          print(
              '📍 Office location: Lat ${officeData['latitude']}, Lon ${officeData['longitude']}');

          setState(() {
            _officeData = officeData;
            _isLoading = false;
          });
        } else {
          _useFallbackOfficeData("No offices found in API response");
        }
      } else {
        final errorMsg =
            'Failed to load office data: Server returned ${response.statusCode}';
        print('📍 Error: $errorMsg');
        _useFallbackOfficeData(errorMsg);
      }
    } catch (e) {
      _handleNetworkError(e);
      final errorMsg = 'Failed to load office data: ${e.toString()}';
      print('📍 Error: $errorMsg');
      _useFallbackOfficeData(errorMsg);
    }
  }

  // Use fallback office data for testing
  void _useFallbackOfficeData(String reason) {
    print('📍 Using fallback office data. Reason: $reason');
    setState(() {
      _officeData = {
        'id': 1,
        'name': 'Test Office',
        'address': 'Test Address for Development',
        'latitude': 0.0,
        'longitude': 0.0,
      };
      _isLoading = false;
    });
  }

  // Helper method to get auth headers
  Future<Map<String, String>> _getAuthHeaders([String? contentType]) async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': contentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper method for handling network errors
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfficeData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOfficeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_officeData == null) {
      return const Center(
        child: Text('No office assigned. Please contact your administrator.'),
      );
    }

    return ManagerCheckInCard(
      officeId: _officeData!['id'],
      officeName: _officeData!['name'],
      officeAddress: _officeData!['address'],
    );
  }
}
