import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/version_check_service.dart';

class VersionController extends GetxController {
  final VersionCheckService _versionService = VersionCheckService();
  final GetStorage _storage = GetStorage();

  final RxBool isCheckingUpdate = false.obs;
  final RxBool hasUpdate = false.obs;
  final RxString currentVersion = ''.obs;
  final RxString storeVersion = ''.obs;
  final RxString releaseNotes = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentVersion();
  }

  /// Load current app version
  Future<void> _loadCurrentVersion() async {
    try {
      final versionInfo = await _versionService.getCurrentVersionInfo();
      currentVersion.value =
          '${versionInfo['version']} (${versionInfo['buildNumber']})';
    } catch (e) {
      currentVersion.value = 'Unknown';
    }
  }

  /// Check for updates with loading state
  Future<void> checkForUpdates({bool showDialog = true}) async {
    if (isCheckingUpdate.value) return;

    isCheckingUpdate.value = true;
    try {
      await _versionService.checkForUpdates(showDialog: showDialog);
    } finally {
      isCheckingUpdate.value = false;
    }
  }

  /// Check for updates silently and update state
  Future<void> checkForUpdatesSilently() async {
    if (isCheckingUpdate.value) return;

    isCheckingUpdate.value = true;
    try {
      hasUpdate.value = await _versionService.checkForUpdatesSilently();
    } finally {
      isCheckingUpdate.value = false;
    }
  }

  /// Check if should show update reminder based on last check time
  Future<bool> shouldShowUpdateReminder() async {
    try {
      final lastCheckTime = _storage.read('last_update_check');
      final now = DateTime.now();

      // Check if 24 hours have passed since last check
      if (lastCheckTime != null) {
        final lastCheck = DateTime.parse(lastCheckTime);
        if (now.difference(lastCheck).inHours < 24) {
          return false;
        }
      }

      // Update last check time
      _storage.write('last_update_check', now.toIso8601String());

      return await _versionService.shouldShowUpdateReminder();
    } catch (e) {
      return false;
    }
  }

  /// Show update reminder if conditions are met
  Future<void> showUpdateReminderIfNeeded() async {
    try {
      final shouldShow = await shouldShowUpdateReminder();
      if (shouldShow) {
        await checkForUpdates(showDialog: true);
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  /// Force check for updates (ignoring time restrictions)
  Future<void> forceCheckForUpdates() async {
    await checkForUpdates(showDialog: true);
  }

  /// Get update status for UI display
  String get updateStatus {
    if (isCheckingUpdate.value) {
      return 'Checking for updates...';
    } else if (hasUpdate.value) {
      return 'Update available';
    } else {
      return 'Up to date';
    }
  }
}
