import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/pages/update/update_page.dart';

class VersionService {
  static const String _lastCheckKey = 'last_version_check';
  static const String _versionDataKey = 'version_data';
  static const Duration _checkInterval =
      Duration(hours: 12); // Check twice per day

  static final GetStorage _storage = GetStorage();

  /// Check version during normal API calls (non-blocking)
  static Future<void> checkVersionSilently() async {
    try {
      // Check if we should perform version check
      if (!_shouldCheckVersion()) {
        return;
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Get server version
      final versionData = await _getServerVersion();
      if (versionData == null) return;

      final serverVersion = versionData['version'] as String;
      final serverBuildNumber =
          int.tryParse(versionData['buildNumber']?.toString() ?? '0') ?? 0;
      final forceUpdate = versionData['forceUpdate'] as bool? ?? false;
      final minRequiredVersion =
          versionData['minRequiredVersion'] as String? ?? '1.0.0';

      // Compare versions
      if (_isUpdateRequired(currentVersion, currentBuildNumber, serverVersion,
          serverBuildNumber, minRequiredVersion)) {
        // Store version data for update page
        _storage.write(_versionDataKey, versionData);

        // Trigger update page navigation
        _showUpdateDialog(versionData, forceUpdate);
      }

      // Update last check time
      _storage.write(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Version check error: $e');
    }
  }

  /// Check if we should perform version check based on time interval
  static bool _shouldCheckVersion() {
    final lastCheckStr = _storage.read<String>(_lastCheckKey);
    if (lastCheckStr == null) return true;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return true;

    final now = DateTime.now();
    return now.difference(lastCheck) >= _checkInterval;
  }

  /// Get server version information
  static Future<Map<String, dynamic>?> _getServerVersion() async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/version'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching server version: $e');
    }
    return null;
  }

  /// Compare versions to determine if update is required
  static bool _isUpdateRequired(
    String currentVersion,
    int currentBuildNumber,
    String serverVersion,
    int serverBuildNumber,
    String minRequiredVersion,
  ) {
    // Parse version strings (e.g., "1.0.3" -> [1, 0, 3])
    final current = _parseVersion(currentVersion);
    final server = _parseVersion(serverVersion);
    final minimum = _parseVersion(minRequiredVersion);

    // Check if server version is higher than current
    if (_compareVersions(server, current) > 0) {
      return true;
    }

    // Check if current version is below minimum required
    if (_compareVersions(current, minimum) < 0) {
      return true;
    }

    return false;
  }

  /// Parse version string to list of integers
  static List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// Compare two version lists
  static int _compareVersions(List<int> v1, List<int> v2) {
    final maxLength = v1.length > v2.length ? v1.length : v2.length;

    for (int i = 0; i < maxLength; i++) {
      final num1 = i < v1.length ? v1[i] : 0;
      final num2 = i < v2.length ? v2[i] : 0;

      if (num1 > num2) return 1;
      if (num1 < num2) return -1;
    }

    return 0;
  }

  /// Show update dialog
  static void _showUpdateDialog(
      Map<String, dynamic> versionData, bool forceUpdate) {
    // Use GetX to show dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpdatePage(versionData, forceUpdate);
    });
  }

  /// Show update page
  static void _showUpdatePage(
      Map<String, dynamic> versionData, bool forceUpdate) {
    // Navigate to update page using GetX
    Get.to(
      () => UpdatePage(
        versionData: versionData,
        forceUpdate: forceUpdate,
      ),
      preventDuplicates: true,
    );
  }

  /// Get stored version data
  static Map<String, dynamic>? getStoredVersionData() {
    return _storage.read<Map<String, dynamic>>(_versionDataKey);
  }

  /// Clear stored version data
  static void clearStoredVersionData() {
    _storage.remove(_versionDataKey);
  }

  /// Open app store for update
  static Future<void> openAppStore(Map<String, dynamic> versionData) async {
    try {
      String url;
      if (Platform.isAndroid) {
        url = versionData['androidUrl'] as String? ??
            'https://play.google.com/store/apps/details?id=com.cit.wooshs';
      } else if (Platform.isIOS) {
        url = versionData['iosUrl'] as String? ??
            'https://apps.apple.com/ke/app/woosh-moonsun/id6745750140';
      } else {
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening app store: $e');
    }
  }
}
 