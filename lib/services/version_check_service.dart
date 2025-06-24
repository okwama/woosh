import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/config/version_config.dart';

class VersionInfo {
  final String currentVersion;
  final String latestVersion;
  final bool canUpdate;
  final String? releaseNotes;

  VersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.canUpdate,
    this.releaseNotes,
  });
}

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  Future<VersionInfo?> checkForUpdate(BuildContext context,
      {bool showDialog = true}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Get latest version from your backend API or app store
      final latestVersionInfo = await _getLatestVersionInfo();

      if (latestVersionInfo != null) {
        final latestVersion = latestVersionInfo['version'] as String;
        final latestBuildNumber =
            int.tryParse(latestVersionInfo['buildNumber'] ?? '0') ?? 0;
        final canUpdate = _compareVersions(currentVersion, latestVersion) < 0 ||
            currentBuildNumber < latestBuildNumber;

        final versionInfo = VersionInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          canUpdate: canUpdate,
          releaseNotes: latestVersionInfo['releaseNotes'] as String?,
        );

        if (canUpdate && showDialog) {
          _showUpdateDialog(context, versionInfo);
        }

        return versionInfo;
      }
    } catch (e) {
      // Only log errors in debug mode to reduce console noise
      if (kDebugMode) {
        debugPrint('Error checking for updates: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getLatestVersionInfo() async {
    // Skip API check if disabled or no URL provided
    if (VersionConfig.skipApiCheck || VersionConfig.versionApiUrl.isEmpty) {
      // Option 2: Try app store scraping
      if (VersionConfig.enableStoreFallback) {
        final storeInfo = await _scrapeAppStoreInfo();
        if (storeInfo != null) {
          return storeInfo;
        }
      }

      // Option 3: Return current version as latest (no update needed)
      return await _getCurrentVersionAsLatest();
    }

    try {
      // Option 1: Check from your backend API (only if enabled)
      final response = await http.get(
        Uri.parse(VersionConfig.versionApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: VersionConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'version': data['version'],
          'buildNumber': data['buildNumber'],
          'releaseNotes': data['releaseNotes'],
        };
      }

      // Option 2: Fallback to app store scraping
      if (VersionConfig.enableStoreFallback) {
        return await _scrapeAppStoreInfo();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching latest version info: $e');
      }
    }

    // Option 3: Return current version as latest (no update needed)
    return await _getCurrentVersionAsLatest();
  }

  Future<Map<String, dynamic>> _getCurrentVersionAsLatest() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'releaseNotes': 'No update information available',
      };
    } catch (e) {
      debugPrint('Error getting current version info: $e');
      return {
        'version': '1.0.1',
        'buildNumber': '12',
        'releaseNotes': 'Version information unavailable',
      };
    }
  }

  Future<Map<String, dynamic>?> _scrapeAppStoreInfo() async {
    try {
      String url;
      if (Platform.isAndroid) {
        url = VersionConfig.androidStoreUrl;
      } else if (Platform.isIOS) {
        url = VersionConfig.iosStoreUrl;
      } else {
        return null;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();

        // For Android Play Store
        if (Platform.isAndroid) {
          // Look for version information in the page
          if (body.contains('current version') || body.contains('version')) {
            // Extract version using regex patterns
            final versionRegex = RegExp(
                r'version["\s:]+([0-9]+\.[0-9]+(?:\.[0-9]+)?)',
                caseSensitive: false);
            final match = versionRegex.firstMatch(body);

            if (match != null) {
              return {
                'version': match.group(1) ?? '1.0.1',
                'buildNumber': '12', // Default build number
                'releaseNotes': 'Latest version available on Google Play Store',
              };
            }
          }
        }
        // For iOS App Store
        else if (Platform.isIOS) {
          // App Store typically shows version in meta tags
          if (body.contains('version') || body.contains('current version')) {
            final versionRegex = RegExp(
                r'version["\s:]+([0-9]+\.[0-9]+(?:\.[0-9]+)?)',
                caseSensitive: false);
            final match = versionRegex.firstMatch(body);

            if (match != null) {
              return {
                'version': match.group(1) ?? '1.0.1',
                'buildNumber': '12', // Default build number
                'releaseNotes': 'Latest version available on App Store',
              };
            }
          }
        }

        // Fallback: return current version as latest (no update needed)
        final currentVersion = await getCurrentVersion();
        return {
          'version': currentVersion,
          'buildNumber': await getBuildNumber(),
          'releaseNotes': 'No new version detected',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error scraping app store info: $e');
      }
    }
    return null;
  }

  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    final maxLength =
        v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1 = i < v1Parts.length ? v1Parts[i] : 0;
      final v2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1 < v2) return -1;
      if (v1 > v2) return 1;
    }
    return 0;
  }

  void _showUpdateDialog(BuildContext context, VersionInfo versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Update Available',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of Woosh is available!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Current Version: ${versionInfo.currentVersion}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Latest Version: ${versionInfo.latestVersion}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (versionInfo.releaseNotes != null) ...[
                const SizedBox(height: 12),
                Text(
                  'What\'s New:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  versionInfo.releaseNotes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Later',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                launchStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> launchStore() async {
    try {
      String url;
      if (Platform.isAndroid) {
        url = VersionConfig.androidStoreUrl;
      } else if (Platform.isIOS) {
        url = VersionConfig.iosStoreUrl;
      } else {
        return;
      }

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error launching store: $e');
      }
    }
  }

  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Error getting current version: $e');
      return 'Unknown';
    }
  }

  Future<String> getBuildNumber() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      debugPrint('Error getting build number: $e');
      return 'Unknown';
    }
  }

  Future<Map<String, String>> getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      debugPrint('Error getting app info: $e');
      return {
        'appName': 'Unknown',
        'packageName': 'Unknown',
        'version': 'Unknown',
        'buildNumber': 'Unknown',
      };
    }
  }
}
