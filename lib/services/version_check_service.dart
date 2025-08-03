import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';
import 'package:get/get.dart';
import 'package:woosh/pages/update/update_page.dart';

class VersionCheckService {
  static const String _lastCheckKey = 'last_version_check';
  static const String _versionDataKey = 'version_data';
  static const Duration _checkInterval =
      Duration(hours: 12); // Check twice per day

  static final GetStorage _storage = GetStorage();

  /// Check version during normal API calls (non-blocking)
  static Future<void> checkVersionSilently() async {
    try {
      print('🔍 Version check started...');

      // Check if we should perform version check
      if (!_shouldCheckVersion()) {
        print('🔍 Version check skipped - too recent');
        return;
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      print(
          '🔍 Current app version: $currentVersion (build $currentBuildNumber)');

      // Get server version
      final versionData = await _getServerVersion();
      if (versionData == null) {
        print('🔍 No server version data received');
        return;
      }

      final serverVersion = versionData['version'] as String;
      final serverBuildNumber =
          int.tryParse(versionData['buildNumber']?.toString() ?? '0') ?? 0;
      final forceUpdate = versionData['forceUpdate'] as bool? ?? false;
      final minRequiredVersion =
          versionData['minRequiredVersion'] as String? ?? '1.0.0';

      print('🔍 Server version: $serverVersion (build $serverBuildNumber)');
      print('🔍 Force update: $forceUpdate');

      // Compare versions
      if (_isUpdateRequired(currentVersion, currentBuildNumber, serverVersion,
          serverBuildNumber, minRequiredVersion)) {
        print('🔍 Update required! Triggering update page...');
        // Store version data for update page
        _storage.write(_versionDataKey, versionData);

        // Trigger update page navigation
        _showUpdateDialog(versionData, forceUpdate);
      } else {
        print('🔍 No update required');
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
    if (lastCheckStr == null) {
      print('🔍 No previous check found - will check');
      return true;
    }

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) {
      print('🔍 Invalid last check time - will check');
      return true;
    }

    final now = DateTime.now();
    final timeSinceLastCheck = now.difference(lastCheck);
    print(
        '🔍 Time since last check: $timeSinceLastCheck (interval: $_checkInterval)');

    final shouldCheck = timeSinceLastCheck >= _checkInterval;
    print('🔍 Should check version: $shouldCheck');
    return shouldCheck;
  }

  /// Get server version information
  static Future<Map<String, dynamic>?> _getServerVersion() async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        print('🔍 No auth token for version check');
        return null;
      }

      print('🔍 Fetching server version from ${Config.baseUrl}/version');
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/version'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 Server version response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Server version data: $data');
        return data;
      } else {
        print('🔍 Server version error: ${response.body}');
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

    print('🔍 Version comparison:');
    print('🔍 Current: $currentVersion -> $current');
    print('🔍 Server: $serverVersion -> $server');
    print('🔍 Minimum: $minRequiredVersion -> $minimum');

    // Check if server version is higher than current
    final serverVsCurrent = _compareVersions(server, current);
    print('🔍 Server vs Current: $serverVsCurrent');

    if (serverVsCurrent > 0) {
      print('🔍 Server version is higher - update required');
      return true;
    }

    // Check if current version is below minimum required
    final currentVsMinimum = _compareVersions(current, minimum);
    print('🔍 Current vs Minimum: $currentVsMinimum');

    if (currentVsMinimum < 0) {
      print('🔍 Current version below minimum - update required');
      return true;
    }

    print('🔍 No update required');
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
    print('🔍 Showing update dialog...');
    // Use GetX to show dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpdatePage(versionData, forceUpdate);
    });
  }

  /// Show update page
  static void _showUpdatePage(
      Map<String, dynamic> versionData, bool forceUpdate) {
    print('🔍 Navigating to update page...');
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

  /// Clear last check time to force version check
  static void clearLastCheckTime() {
    _storage.remove(_lastCheckKey);
    print('🔍 Cleared last check time - next check will run');
  }

  /// Force version check (for testing)
  static Future<void> forceVersionCheck() async {
    print('🔍 Force version check triggered');
    _storage.remove(_lastCheckKey);
    await checkVersionSilently();
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
