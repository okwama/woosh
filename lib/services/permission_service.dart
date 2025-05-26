import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PermissionService {
  static Future<void> requestInitialPermissions() async {
    // Request location permission
    final locationStatus = await Permission.location.request();
    if (locationStatus.isDenied) {
      _showPermissionDialog(
        'Location Permission Required',
        'This app needs location access to enable check-ins and track your visits.',
        Permission.location,
      );
    }

    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied) {
      _showPermissionDialog(
        'Camera Permission Required',
        'This app needs camera access to capture photos for reports and check-ins.',
        Permission.camera,
      );
    }

    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus.isDenied) {
      _showPermissionDialog(
        'Notification Permission Required',
        'This app needs notification access to keep you updated about your visits and tasks.',
        Permission.notification,
      );
    }
  }

  static void _showPermissionDialog(
    String title,
    String message,
    Permission permission,
  ) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
