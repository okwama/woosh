import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:woosh/services/version/version_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';

class UpdatePage extends StatefulWidget {
  final Map<String, dynamic> versionData;
  final bool forceUpdate;

  const UpdatePage({
    super.key,
    required this.versionData,
    this.forceUpdate = false,
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  String _currentVersion = '';
  String _currentBuildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
        _currentBuildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      print('Error loading current version: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverVersion = widget.versionData['version'] as String? ?? 'Unknown';
    final serverBuildNumber =
        widget.versionData['buildNumber']?.toString() ?? 'Unknown';
    final updateMessage = widget.versionData['updateMessage'] as String? ??
        'A new version is available';
    final forceUpdate = widget.versionData['forceUpdate'] as bool? ?? false;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation if force update is required
        if (forceUpdate || widget.forceUpdate) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: appBackground,
        appBar: GradientAppBar(
          title: 'Update Required',
          automaticallyImplyLeading: !forceUpdate && !widget.forceUpdate,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Update Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  forceUpdate || widget.forceUpdate
                      ? 'Update Required'
                      : 'Update Available',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  updateMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Version Comparison
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Version:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$_currentVersion (Build $_currentBuildNumber)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Latest Version:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$serverVersion (Build $serverBuildNumber)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Update Button
                SizedBox(
                  width: double.infinity,
                  child: GoldGradientButton(
                    onPressed: () => _openAppStore(),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Later Button (only if not forced)
                if (!forceUpdate && !widget.forceUpdate)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Platform-specific info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Platform.isAndroid ? Icons.android : Icons.apple,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Platform.isAndroid
                              ? 'Update will open Google Play Store'
                              : 'Update will open App Store',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAppStore() async {
    try {
      await VersionService.openAppStore(widget.versionData);
    } catch (e) {
      print('Error opening app store: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening app store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
