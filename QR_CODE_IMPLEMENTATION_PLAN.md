# QR Code Implementation Plan

## Overview
This document outlines a plan to enhance the existing check-in/check-out system by implementing QR code scanning functionality. This will allow guards to verify their presence at specific locations by scanning QR codes placed at those locations.

## Current System Assessment

The current system relies on geofencing to verify guard location:
- Uses GPS coordinates
- Verifies proximity using the Haversine formula
- Requires guards to be within a specific radius of a location

## Proposed QR Code Enhancement

### Benefits
1. **Improved Location Verification**: QR codes ensure guards are at the exact required location, not just within a radius
2. **Reduced GPS Dependency**: Less reliant on GPS accuracy, which can be affected by buildings/environments
3. **Better Accountability**: Guards must physically scan codes, creating a verifiable record of presence
4. **Improved User Experience**: Clear indication of exact check-in/check-out points

### Technical Requirements

#### 1. Dependencies
Add the following to `pubspec.yaml`:
```yaml
dependencies:
  qr_code_scanner: ^1.0.1  # For scanning QR codes using camera
  qr_flutter: ^4.1.0       # For generating QR codes (admin/supervisor use)
```

#### 2. Models Update
Enhance `JourneyPlan` model in `lib/models/journeyplan_model.dart`:
```dart
class JourneyPlan {
  // Add new fields
  final String? qrCodeId;          // Unique ID embedded in QR code
  final DateTime? qrScanTime;      // When QR was scanned
  final bool? isQrVerified;        // Whether location was verified by QR

  // Update constructor
  JourneyPlan({
    // Existing parameters
    this.qrCodeId,
    this.qrScanTime,
    this.isQrVerified,
  });

  // Update copyWith method
  JourneyPlan copyWith({
    // Existing parameters
    String? qrCodeId,
    DateTime? qrScanTime,
    bool? isQrVerified,
  }) {
    return JourneyPlan(
      // Existing parameters
      qrCodeId: qrCodeId ?? this.qrCodeId,
      qrScanTime: qrScanTime ?? this.qrScanTime,
      isQrVerified: isQrVerified ?? this.isQrVerified,
    );
  }

  // Update fromJson and toJson methods
}
```

#### 3. API Service Enhancement
Update `ApiService` in `lib/services/api_service.dart`:

```dart
static Future<JourneyPlan> updateJourneyPlanWithQR({
  required int journeyId,
  required int outletId,
  required String qrCodeId,
  int? status,
  DateTime? checkInTime,
  double? latitude,
  double? longitude,
  String? imageUrl,
  String? notes,
}) async {
  try {
    final token = _getAuthToken();
    if (token == null) {
      throw Exception("Authentication token is missing");
    }

    final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

    // Convert numeric status to string status for the API
    String? statusString;
    if (status != null) {
      // Existing conversion logic
    }

    final body = {
      'outletId': outletId,
      if (statusString != null) 'status': statusString,
      if (checkInTime != null) 'checkInTime': checkInTime.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (notes != null) 'notes': notes,
      'qrCodeId': qrCodeId,
      'qrScanTime': DateTime.now().toIso8601String(),
      'isQrVerified': true,
    };

    // Debug logging
    print('API REQUEST - QR CODE CHECK-IN:');
    print('URL: $url');
    print('Journey ID: $journeyId');
    print('QR Code ID: $qrCodeId');
    print('Status: $statusString');

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    // Process response and return
    // Similar to existing updateJourneyPlan method
  } catch (e) {
    // Error handling
  }
}
```

#### 4. QR Scanner Component
Create a new file `lib/components/qr_scanner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:get/get.dart';

class QRScannerView extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final String title;
  final String instruction;

  const QRScannerView({
    Key? key,
    required this.onQRCodeScanned,
    this.title = 'Scan QR Code',
    this.instruction = 'Align QR code within the frame',
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: _buildQrView(context),
          ),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(widget.instruction),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () async {
                            await controller?.toggleFlash();
                            setState(() {});
                          },
                          icon: FutureBuilder(
                            future: controller?.getFlashStatus(),
                            builder: (context, snapshot) {
                              return Icon(
                                snapshot.data == true
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () async {
                            await controller?.flipCamera();
                            setState(() {});
                          },
                          icon: const Icon(Icons.flip_camera_ios),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).primaryColor,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      if (!isProcessing && scanData.code != null) {
        setState(() {
          isProcessing = true;
        });
        
        // Process QR code
        widget.onQRCodeScanned(scanData.code!);
        
        // Vibrate
        HapticFeedback.heavyImpact();
        
        // Close scanner
        Get.back();
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
```

#### 5. Journey View Updates
Modify `lib/pages/journeyplan/journeyview.dart` to add QR scanning:

```dart
// Add import
import 'package:woosh/components/qr_scanner.dart';

// Add scanning method
Future<void> _scanQRCodeForCheckIn() async {
  try {
    // Show QR scanner
    await Get.to(() => QRScannerView(
      onQRCodeScanned: (qrData) async {
        // Process scanned QR code
        await _processQRCheckIn(qrData);
      },
      title: 'Scan Location QR Code',
      instruction: 'Scan the QR code at your assigned location',
    ));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error scanning QR code: $e')),
    );
  }
}

// Add QR processing method
Future<void> _processQRCheckIn(String qrData) async {
  try {
    setState(() {
      _isCheckingIn = true;
    });
    
    // Validate the QR code format
    // Expecting format like: "WOOSH_LOC_123" where 123 is location ID
    if (!qrData.startsWith('WOOSH_LOC_')) {
      throw Exception('Invalid QR code format');
    }
    
    // Extract location ID from QR code
    final qrCodeId = qrData;
    
    // Get current position for additional verification
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    // Take check-in photo if needed (use existing photo function)
    final String? imageUrl = await _takeCheckInPhoto();
    
    // Update journey plan with QR data
    final updatedPlan = await ApiService.updateJourneyPlanWithQR(
      journeyId: widget.journeyPlan.id!,
      outletId: widget.journeyPlan.outletId,
      qrCodeId: qrCodeId,
      status: JourneyPlan.statusCheckedIn,
      checkInTime: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      imageUrl: imageUrl,
    );
    
    // Success handling similar to existing check-in
    // Show success message and update UI
    
  } catch (e) {
    // Error handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error processing QR check-in: $e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isCheckingIn = false;
      });
    }
  }
}

// Update the UI to add QR check-in button
// In the buildFloatingActionButton method
FloatingActionButton.extended(
  onPressed: (_isCheckingIn)
      ? null
      : _scanQRCodeForCheckIn,
  icon: const Icon(Icons.qr_code_scanner),
  label: const Text('Scan QR to Check In'),
)
```

#### 6. QR Generation for Administrators
Create a new file `lib/pages/admin/qr_generator_page.dart` for admins to generate location QR codes:

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class QRGeneratorPage extends StatefulWidget {
  const QRGeneratorPage({Key? key}) : super(key: key);

  @override
  _QRGeneratorPageState createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  Outlet? _selectedOutlet;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      final outlets = await ApiService.fetchOutlets();
      setState(() {
        _outlets = outlets;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading outlets: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _generateQRData(Outlet outlet) {
    // Format: WOOSH_LOC_{outlet_id}
    return 'WOOSH_LOC_${outlet.id}';
  }

  Future<void> _shareQRCode() async {
    if (_selectedOutlet == null) return;

    try {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/qr_code_${_selectedOutlet!.id}.png';
      
      final image = await _screenshotController.captureAndSave(
        directory.path,
        fileName: 'qr_code_${_selectedOutlet!.id}.png',
      );
      
      if (image != null) {
        await Share.shareFiles(
          [imagePath],
          text: 'QR Code for ${_selectedOutlet!.name}',
          subject: 'Location QR Code',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Generator'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Outlet>(
                    decoration: const InputDecoration(
                      labelText: 'Select Location',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedOutlet,
                    items: _outlets.map((outlet) {
                      return DropdownMenuItem(
                        value: outlet,
                        child: Text(outlet.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedOutlet = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_selectedOutlet != null) ...[
                    Center(
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: _generateQRData(_selectedOutlet!),
                                version: QrVersions.auto,
                                size: 200.0,
                                embeddedImage: 
                                    const AssetImage('assets/images/logo.png'),
                                embeddedImageStyle: QrEmbeddedImageStyle(
                                  size: const Size(40, 40),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedOutlet!.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _selectedOutlet!.address,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _shareQRCode,
                      icon: const Icon(Icons.share),
                      label: const Text('Share QR Code'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final image = await _screenshotController.capture();
                        if (image != null) {
                          // Save image to gallery
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Save QR Code'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
```

### Backend API Updates

The backend will need new endpoints to support QR code validation:

1. Update the `journey-plans` endpoint to accept `qrCodeId` parameter
2. Add validation logic to verify QR codes match assigned locations
3. Store QR scan data for audit and reporting purposes

## Implementation Phases

### Phase 1: Setup and Infrastructure
1. Add required dependencies to pubspec.yaml
2. Update JourneyPlan model to support QR data
3. Create QR Scanner component

### Phase 2: Check-in Integration
1. Implement QR code scanning in journey view
2. Update API service to support QR verification
3. Test QR-based check-in flow

### Phase 3: Check-out Integration
1. Add QR scanning to checkout process
2. Update API endpoints for checkout with QR
3. Test complete journey flow

### Phase 4: Admin Features
1. Create QR code generator for administrators
2. Build reporting on QR scan compliance
3. Implement QR code management system

## Testing Plan
1. **Unit Tests**: Verify QR code parsing and validation
2. **Integration Tests**: Test full check-in/check-out flow with QR codes
3. **Field Testing**: Deploy to a small group of users for real-world testing
4. **Security Testing**: Ensure QR codes cannot be spoofed or replicated

## Future Enhancements
1. **Offline QR Scanning**: Store scanned QR codes when offline, sync later
2. **Dynamic QR Codes**: Time-based QR codes that change periodically
3. **NFC Integration**: Support for NFC tags as an alternative to QR codes
4. **Biometric Verification**: Add facial recognition alongside QR scanning 