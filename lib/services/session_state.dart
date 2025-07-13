import 'package:get/get.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/models/hive/session_model.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';

class SessionState extends GetxController {
  final isSessionActive = false.obs;
  final sessionStartTime = Rxn<DateTime>();
  final isCheckingSession = false.obs;
  final lastCheckTime = Rxn<DateTime>();

  // Cache duration - until user explicitly ends session
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Services
  final SessionHiveService _sessionHiveService = SessionHiveService();
  Timer? _periodicCheckTimer;

  @override
  void onInit() {
    super.onInit();
    _initSessionState();
    _startPeriodicChecks();
  }

  @override
  void onClose() {
    _periodicCheckTimer?.cancel();
    super.onClose();
  }

  /// Initialize session state from cache or API
  Future<void> _initSessionState() async {
    await _sessionHiveService.init();

    // Use cached data immediately for faster startup
    final cachedSession = await _sessionHiveService.getSession();
    if (cachedSession != null) {
      _updateSessionState(cachedSession.isActive, cachedSession.loginTime);
      print('✅ Session state initialized from cache');
    }

    // Check API in background (non-blocking)
    _checkSessionInBackground();
  }

  /// Check session status in background
  Future<void> _checkSessionInBackground() async {
    try {
      await Future.delayed(
          const Duration(seconds: 1)); // Small delay to prioritize UI
      await checkSessionStatus();
    } catch (e) {
      print('⚠️ Background session check failed: $e');
    }
  }

  /// Start periodic session checks (only when session is inactive)
  void _startPeriodicChecks() {
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // Only check if session is not active (to avoid unnecessary API calls)
      if (!isSessionActive.value) {
        checkSessionStatus();
      }
    });
  }

  /// Single source of truth for session status check
  Future<bool> checkSessionStatus() async {
    // Prevent multiple simultaneous checks
    if (isCheckingSession.value) {
      return isSessionActive.value;
    }

    isCheckingSession.value = true;

    try {
      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        print('🔍 Session check: No user ID found');
        _updateSessionState(false, null);
        return false;
      }

      print('🔍 Session check: User ID = $userId');

      // Check cache first
      final cachedSession = await _sessionHiveService.getSession();
      print('🔍 Session check: Cached session = ${cachedSession?.isActive}');

      // If session is active in cache, use it (don't check API)
      if (cachedSession != null && cachedSession.isActive) {
        print('🔍 Session check: Using cached active session');
        _updateSessionState(cachedSession.isActive, cachedSession.loginTime);
        return cachedSession.isActive;
      }

      // If session is inactive in cache, check if cache is still valid
      if (cachedSession != null &&
          !cachedSession.isActive &&
          _isCacheValid(cachedSession)) {
        print('🔍 Session check: Using cached inactive session');
        _updateSessionState(cachedSession.isActive, cachedSession.loginTime);
        return cachedSession.isActive;
      }

      // Cache expired or doesn't exist, check API
      print('🔍 Session check: Cache expired or no cache, checking API...');
      final isActive = await SessionService.isSessionActive(userId);
      print('🔍 Session check: API result = $isActive');

      // Get additional session details
      DateTime? loginTime;
      try {
        final response = await SessionService.getSessionHistory(userId);
        final sessions = response['sessions'] as List;
        if (sessions.isNotEmpty) {
          final lastSession = sessions.first;
          loginTime = DateTime.parse(lastSession['loginAt']);
        }
      } catch (e) {
        print('Error getting session details: $e');
      }

      // Update cache
      await _sessionHiveService.saveSession(SessionModel(
        isActive: isActive,
        lastCheck: DateTime.now(),
        loginTime: loginTime,
        userId: userId,
      ));

      _updateSessionState(isActive, loginTime);
      return isActive;
    } catch (e) {
      print('Error checking session status: $e');

      // Fallback to cached data if available
      final cachedSession = await _sessionHiveService.getSession();
      if (cachedSession != null) {
        _updateSessionState(cachedSession.isActive, cachedSession.loginTime);
        return cachedSession.isActive;
      }

      return false;
    } finally {
      isCheckingSession.value = false;
    }
  }

  /// Check if cache is still valid (only for inactive sessions)
  bool _isCacheValid(SessionModel? cachedSession) {
    if (cachedSession == null || cachedSession.lastCheck == null) {
      return false;
    }

    // If session is active, cache is always valid until user ends it
    if (cachedSession.isActive) {
      return true;
    }

    // For inactive sessions, use time-based cache
    final timeSinceLastCheck =
        DateTime.now().difference(cachedSession.lastCheck!);
    return timeSinceLastCheck < _cacheDuration;
  }

  /// Update session state (single source of truth)
  void _updateSessionState(bool active, DateTime? startTime) {
    isSessionActive.value = active;
    sessionStartTime.value = startTime;
    lastCheckTime.value = DateTime.now();
  }

  /// Public method to update session state (used by session operations)
  void updateSessionState(bool active, DateTime? startTime) {
    _updateSessionState(active, startTime);

    // Update cache immediately
    _updateCache(active, startTime);
  }

  /// Update cache with new session state
  Future<void> _updateCache(bool active, DateTime? startTime) async {
    try {
      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId != null) {
        await _sessionHiveService.saveSession(SessionModel(
          isActive: active,
          lastCheck: DateTime.now(),
          loginTime: startTime,
          userId: userId,
        ));

        print('✅ Session cache updated: active=$active, startTime=$startTime');
      }
    } catch (e) {
      print('Error updating session cache: $e');
    }
  }

  /// Force refresh session status (bypass cache)
  Future<bool> forceRefreshSessionStatus() async {
    // Clear cache to force API call
    await _sessionHiveService.clearSession();
    return await checkSessionStatus();
  }

  /// Check if user can access features that require active session
  bool canAccessFeature() {
    return isSessionActive.value;
  }

  /// Check if session has expired (9-hour shift)
  bool isSessionExpired() {
    if (sessionStartTime.value == null) return true;
    final now = DateTime.now();
    return now.difference(sessionStartTime.value!).inHours >= 9;
  }

  /// Get session duration as formatted string
  String get sessionDuration {
    if (sessionStartTime.value == null) return 'N/A';

    final now = DateTime.now();
    final duration = now.difference(sessionStartTime.value!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Clear session state (for logout)
  Future<void> clearSession() async {
    _updateSessionState(false, null);
    await _sessionHiveService.clearSession();
  }

  /// Start session and cache it (called when user starts session)
  Future<void> startSession() async {
    final box = GetStorage();
    final userId = box.read<String>('userId');

    if (userId != null) {
      final now = DateTime.now();
      _updateSessionState(true, now);
      await _updateCache(true, now);
      print('✅ Session started and cached');
    }
  }

  /// End session and clear cache (called when user ends session)
  Future<void> endSession() async {
    final box = GetStorage();
    final userId = box.read<String>('userId');

    if (userId != null) {
      // Call API to end session
      try {
        await SessionService.recordLogout(userId);
        print('✅ Session ended via API');
      } catch (e) {
        print('⚠️ Failed to end session via API: $e');
      }

      // Clear local cache and state
      _updateSessionState(false, null);
      await _sessionHiveService.clearSession();
      print('✅ Session cache cleared');
    }
  }

  /// Debug method to check session status step by step
  Future<void> debugSessionStatus() async {
    print('🔍 DEBUG SESSION STATUS START');

    final box = GetStorage();
    final userId = box.read<String>('userId');
    print('🔍 User ID: $userId');

    if (userId == null) {
      print('❌ No user ID found - session inactive');
      return;
    }

    // Check cache
    final cachedSession = await _sessionHiveService.getSession();
    print('🔍 Cached session: ${cachedSession?.isActive}');
    print('🔍 Cache valid: ${_isCacheValid(cachedSession)}');

    if (cachedSession != null) {
      print('🔍 Cache details:');
      print('   - isActive: ${cachedSession.isActive}');
      print('   - lastCheck: ${cachedSession.lastCheck}');
      print('   - loginTime: ${cachedSession.loginTime}');
      print('   - userId: ${cachedSession.userId}');
    }

    // Check API
    try {
      print('🔍 Checking API...');
      final isActive = await SessionService.isSessionActive(userId);
      print('🔍 API says session active: $isActive');

      // Get detailed session info
      final response = await SessionService.getSessionHistory(userId);
      final sessions = response['sessions'] as List;
      print('🔍 Total sessions found: ${sessions.length}');

      if (sessions.isNotEmpty) {
        final lastSession = sessions.first;
        print('🔍 Last session details:');
        print('   - status: ${lastSession['status']}');
        print('   - loginAt: ${lastSession['loginAt']}');
        print('   - logoutAt: ${lastSession['logoutAt']}');
        print('   - sessionStart: ${lastSession['sessionStart']}');
        print('   - sessionEnd: ${lastSession['sessionEnd']}');
        print('   - duration: ${lastSession['duration']}');
        print('   - isLate: ${lastSession['isLate']}');
        print('   - isEarly: ${lastSession['isEarly']}');
      } else {
        print('❌ No sessions found in API response');
      }
    } catch (e) {
      print('❌ API error: $e');
    }

    // Check current state
    print('🔍 Current state:');
    print('   - isSessionActive: ${isSessionActive.value}');
    print('   - sessionStartTime: ${sessionStartTime.value}');
    print('   - isCheckingSession: ${isCheckingSession.value}');
    print('   - lastCheckTime: ${lastCheckTime.value}');

    print('🔍 DEBUG SESSION STATUS END');
  }
}
