import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/clockInOut/clock_in_out_service.dart';
import 'dart:async';

/// Clock In/Out State Controller
///
/// Manages the clock in/out state across the app:
/// - isClockedIn: Current clock status
/// - currentSessionStart: When current session started
/// - currentDuration: Current session duration in minutes
/// - isLoading: Loading state for operations
class ClockInOutState extends GetxController {
  // Observable variables
  final isClockedIn = false.obs;
  final currentSessionStart = Rxn<String>();
  final currentDuration = 0.obs;
  final isLoading = false.obs;
  final lastCheckTime = Rxn<DateTime>();

  // Timer for updating duration
  Timer? _durationTimer;

  // Storage for caching
  final _storage = GetStorage();
  static const String _clockCacheKey = 'clock_session_cache';

  @override
  void onInit() {
    super.onInit();
    _loadCachedSession();
    _initClockState();
  }

  @override
  void onClose() {
    _durationTimer?.cancel();
    super.onClose();
  }

  /// Load cached session data
  void _loadCachedSession() {
    try {
      final cachedData = _storage.read(_clockCacheKey);
      if (cachedData != null) {
        isClockedIn.value = cachedData['isClockedIn'] ?? false;
        currentSessionStart.value = cachedData['sessionStart'];
        currentDuration.value = cachedData['duration'] ?? 0;

        if (isClockedIn.value) {
          print(
              '✅ Loaded cached session: Clocked in at ${currentSessionStart.value}');
          _startDurationTimer();
        }
      }
    } catch (e) {
      print('❌ Error loading cached session: $e');
    }
  }

  /// Cache current session data
  void _cacheSession() {
    try {
      final sessionData = {
        'isClockedIn': isClockedIn.value,
        'sessionStart': currentSessionStart.value,
        'duration': currentDuration.value,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      _storage.write(_clockCacheKey, sessionData);
      print('💾 Cached session data');
    } catch (e) {
      print('❌ Error caching session: $e');
    }
  }

  /// Clear cached session data
  void _clearCache() {
    try {
      _storage.remove(_clockCacheKey);
      print('🗑️ Cleared session cache');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Initialize clock state
  Future<void> _initClockState() async {
    // If we have cached session, use it; otherwise check API
    if (!isClockedIn.value) {
      await _refreshStatus();
    }
    _startDurationTimer();
  }

  /// Start timer to update duration every minute
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (isClockedIn.value) {
        _updateDuration();
        _cacheSession(); // Update cache with new duration
      }
    });
  }

  /// Update current duration
  void _updateDuration() {
    if (currentSessionStart.value != null) {
      final startTime = DateTime.parse(currentSessionStart.value!);
      final now = DateTime.now();
      final duration = now.difference(startTime).inMinutes;
      currentDuration.value = duration;
    }
  }

  /// Refresh clock status from API
  Future<void> _refreshStatus() async {
    try {
      isLoading.value = true;

      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        print('❌ No user ID found for clock status');
        return;
      }

      final status = await ClockInOutService.getCurrentStatus(userId);

      isClockedIn.value = status['isClockedIn'] ?? false;
      currentSessionStart.value = status['sessionStart'];
      currentDuration.value = status['duration'] ?? 0;
      lastCheckTime.value = DateTime.now();

      // Cache the status
      if (isClockedIn.value) {
        _cacheSession();
      }

      print(
          '✅ Clock status refreshed: isClockedIn=${isClockedIn.value}, duration=${currentDuration.value}');
    } catch (e) {
      print('❌ Failed to refresh clock status: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Clock In - Start a new session
  Future<bool> clockIn() async {
    try {
      isLoading.value = true;

      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        print('❌ No user ID found for clock in');
        return false;
      }

      print('🟢 Clock In: Starting session...');

      final result = await ClockInOutService.clockIn(userId);

      if (result['success'] == true) {
        // Update state
        isClockedIn.value = true;
        currentSessionStart.value = DateTime.now().toIso8601String();
        currentDuration.value = 0;
        lastCheckTime.value = DateTime.now();

        // Cache the session
        _cacheSession();

        // Start duration timer
        _startDurationTimer();

        print('✅ Clock In successful - Session cached');
        return true;
      } else {
        print('❌ Clock In failed: ${result['message']}');
        return false;
      }
    } catch (e) {
      print('❌ Clock In error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Clock Out - End current session
  Future<bool> clockOut() async {
    try {
      isLoading.value = true;

      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        print('❌ No user ID found for clock out');
        return false;
      }

      print('🔴 Clock Out: Ending session...');

      final result = await ClockInOutService.clockOut(userId);

      if (result['success'] == true) {
        // Update state
        isClockedIn.value = false;
        currentSessionStart.value = null;
        currentDuration.value = 0;
        lastCheckTime.value = DateTime.now();

        // Clear cache
        _clearCache();

        // Stop duration timer
        _durationTimer?.cancel();

        print('✅ Clock Out successful - Cache cleared');
        return true;
      } else {
        print('❌ Clock Out failed: ${result['message']}');
        return false;
      }
    } catch (e) {
      print('❌ Clock Out error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh status manually
  Future<void> refreshStatus() async {
    await _refreshStatus();
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = currentDuration.value ~/ 60;
    final minutes = currentDuration.value % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted session start time
  String get formattedSessionStart {
    if (currentSessionStart.value == null) return 'N/A';

    try {
      final startTime = DateTime.parse(currentSessionStart.value!);
      return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Check if user can access features that require being clocked in
  bool get canAccessFeatures => isClockedIn.value;

  /// Check if there's a cached session
  bool get hasCachedSession {
    try {
      final cachedData = _storage.read(_clockCacheKey);
      return cachedData != null && cachedData['isClockedIn'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get cached session info for debugging
  Map<String, dynamic>? get cachedSessionInfo {
    try {
      return _storage.read(_clockCacheKey);
    } catch (e) {
      return null;
    }
  }

  /// Get session info for journey planning
  Map<String, dynamic>? get sessionInfoForJP {
    if (!isClockedIn.value) return null;

    return {
      'isClockedIn': isClockedIn.value,
      'sessionStart': currentSessionStart.value,
      'duration': currentDuration.value,
      'formattedDuration': formattedDuration,
      'formattedSessionStart': formattedSessionStart,
    };
  }
}
