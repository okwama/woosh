import 'dart:io';
import 'package:flutter/material.dart';
import 'package:new_version/new_version.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  /// Check for app updates and show dialog if new version is available
  Future<void> checkForUpdates({bool showDialog = true}) async {
    try {
      final newVersion = NewVersion();
      final status = await newVersion.getVersionStatus();

      if (status != null && status.canUpdate) {
        if (showDialog) {
          _showUpdateDialog(status);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  /// Check for updates silently (without showing dialog)
  Future<bool> checkForUpdatesSilently() async {
    try {
      final newVersion = NewVersion();
      final status = await newVersion.getVersionStatus();
      return status != null && status.canUpdate;
    } catch (e) {
      debugPrint('Error checking for updates silently: $e');
      return false;
    }
  }

  /// Show update dialog with options
  void _showUpdateDialog(VersionStatus status) {
    Get.dialog(
      AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version (${status.storeVersion}) is available!'),
            const SizedBox(height: 8),
            Text('Current version: ${status.localVersion}'),
            const SizedBox(height: 8),
            if (status.releaseNotes != null && status.releaseNotes!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What\'s new:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(status.releaseNotes!),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _launchStore();
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Launch app store based on platform
  Future<void> _launchStore() async {
    try {
      if (Platform.isAndroid) {
        // Try in-app update first
        await _tryInAppUpdate();
      } else {
        // For iOS, always redirect to App Store
        await _launchAppStore();
      }
    } catch (e) {
      debugPrint('Error launching store: $e');
      // Fallback to direct store launch
      await _launchAppStore();
    }
  }

  /// Try in-app update for Android
  Future<void> _tryInAppUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
        } else {
          await _launchAppStore();
        }
      } else {
        await _launchAppStore();
      }
    } catch (e) {
      debugPrint('In-app update failed: $e');
      await _launchAppStore();
    }
  }

  /// Launch app store directly
  Future<void> _launchAppStore() async {
    try {
      final newVersion = NewVersion();
      await newVersion.launchAppStore();
    } catch (e) {
      debugPrint('Error launching app store: $e');
      // Fallback URLs
      final url = Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=com.cit.wooshs'
          : 'https://apps.apple.com/app/id123456789'; // Replace with your actual App Store ID

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Get current app version info
  Future<Map<String, String>> getCurrentVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return {};
    }
  }

  /// Check if app should show update reminder
  Future<bool> shouldShowUpdateReminder() async {
    try {
      final hasUpdate = await checkForUpdatesSilently();
      if (!hasUpdate) return false;

      // You can add logic here to control how often to show the reminder
      // For example, check last reminder time from local storage
      return true;
    } catch (e) {
      debugPrint('Error checking update reminder: $e');
      return false;
    }
  }
}
