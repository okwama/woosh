import 'package:get/get.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/models/hive/pending_session_model.dart';
import 'package:woosh/models/hive/session_model.dart';

class EnhancedSessionService {
  static late PendingSessionHiveService _pendingSessionService;
  static late SessionHiveService _sessionHiveService;

  static Future<void> initialize() async {
    try {
      _pendingSessionService = Get.find<PendingSessionHiveService>();
    } catch (e) {
      _pendingSessionService = PendingSessionHiveService();
      await _pendingSessionService.init();
      Get.put(_pendingSessionService);
    }

    try {
      _sessionHiveService = Get.find<SessionHiveService>();
    } catch (e) {
      _sessionHiveService = SessionHiveService();
      await _sessionHiveService.init();
      Get.put(_sessionHiveService);
    }
  }

  /// Enhanced session start with offline support
  static Future<Map<String, dynamic>> recordLogin(String userId) async {
    try {
      // Try to record login via API first
      final response = await SessionService.recordLogin(userId);

      if (response['error'] == null) {
        // Success - update local session state
        await _sessionHiveService.saveSession(SessionModel(
          isActive: true,
          lastCheck: DateTime.now(),
          loginTime: DateTime.now(),
          userId: userId,
        ));

        print('✅ Session started successfully (online)');
        return response;
      } else {
        // API returned an error (like early login restriction)
        return response;
      }
    } catch (e) {
      print('❌ Session start failed, checking if server error: $e');

      // Check if it's a server error (500-503)
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('🔄 Server error detected - saving session start for later sync');

        // Save pending session operation
        await _savePendingSessionOperation(userId, 'start');

        // Update local session state optimistically
        await _sessionHiveService.saveSession(SessionModel(
          isActive: true,
          lastCheck: DateTime.now(),
          loginTime: DateTime.now(),
          userId: userId,
        ));

        print(
            '💾 Session start saved locally - will sync when server is available');

        return {
          'success': true,
          'message':
              'Session started locally - will sync when server is available',
          'offline': true,
        };
      } else {
        // Other errors (network, validation, etc.) - rethrow
        rethrow;
      }
    }
  }

  /// Enhanced session end with offline support
  static Future<Map<String, dynamic>> recordLogout(String userId) async {
    try {
      // Check if there are pending session start operations that haven't been synced
      final pendingSessions =
          _pendingSessionService.getPendingSessionsForUser(userId);
      final hasPendingStart = pendingSessions.any((session) =>
          session.operation == 'start' && session.status == 'pending');

      if (hasPendingStart) {
        print('🔄 Found pending session start - ending session locally only');

        // Remove the pending start operation since we're ending the session
        final pendingStartSessions = pendingSessions
            .where((session) =>
                session.operation == 'start' && session.status == 'pending')
            .toList();

        for (final session in pendingStartSessions) {
          await _pendingSessionService
              .deletePendingSession(session.key.toString());
        }

        // Update local session state
        await _sessionHiveService.saveSession(SessionModel(
          isActive: false,
          lastCheck: DateTime.now(),
          loginTime: null,
          userId: userId,
        ));

        print('✅ Session ended locally (cancelled pending start)');
        return {
          'success': true,
          'message': 'Session ended (offline session cancelled)',
          'offline': true,
        };
      }

      // Try to record logout via API first
      await SessionService.recordLogout(userId);

      // Success - update local session state
      await _sessionHiveService.saveSession(SessionModel(
        isActive: false,
        lastCheck: DateTime.now(),
        loginTime: null,
        userId: userId,
      ));

      print('✅ Session ended successfully (online)');
      return {'success': true, 'message': 'Session ended successfully'};
    } catch (e) {
      print('❌ Session end failed, checking if server error: $e');

      // Check if it's "No active session found" error - common when session was started offline
      if (e.toString().contains('No active session found')) {
        print('🔄 No active session on server - ending local session only');

        // Update local session state
        await _sessionHiveService.saveSession(SessionModel(
          isActive: false,
          lastCheck: DateTime.now(),
          loginTime: null,
          userId: userId,
        ));

        print('✅ Local session ended (no server session found)');
        return {
          'success': true,
          'message': 'Session ended locally',
          'offline': true,
        };
      }

      // Check if it's a server error (500-503)
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('🔄 Server error detected - saving session end for later sync');

        // Save pending session operation
        await _savePendingSessionOperation(userId, 'end');

        // Update local session state optimistically
        await _sessionHiveService.saveSession(SessionModel(
          isActive: false,
          lastCheck: DateTime.now(),
          loginTime: null,
          userId: userId,
        ));

        print(
            '💾 Session end saved locally - will sync when server is available');

        return {
          'success': true,
          'message':
              'Session ended locally - will sync when server is available',
          'offline': true,
        };
      } else {
        // Other errors (network, validation, etc.) - rethrow
        rethrow;
      }
    }
  }

  /// Save pending session operation for later sync
  static Future<void> _savePendingSessionOperation(
      String userId, String operation) async {
    final pendingSession = PendingSessionModel(
      userId: userId,
      operation: operation,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    await _pendingSessionService.savePendingSession(pendingSession);
    print('💾 Saved pending $operation operation for user $userId');
  }

  /// Get current session status (from local storage)
  static Future<SessionModel?> getCurrentSession() async {
    return await _sessionHiveService.getSession();
  }

  /// Check if user has pending session operations
  static Future<List<PendingSessionModel>> getPendingOperations(
      String userId) async {
    return _pendingSessionService.getPendingSessionsForUser(userId);
  }

  /// Check session validity with offline support
  static Future<bool> isSessionValid(String userId) async {
    try {
      // Try to check with API first
      return await SessionService.isSessionValid(userId);
    } catch (e) {
      // If API fails, check local session
      final localSession = await _sessionHiveService.getSession();
      if (localSession != null && localSession.userId == userId) {
        // Consider session valid if it was active locally within last hour
        if (localSession.isActive && localSession.lastCheck != null) {
          final difference = DateTime.now().difference(localSession.lastCheck!);
          return difference < const Duration(hours: 1);
        }
      }
      return false;
    }
  }

  /// Get session history with offline support
  static Future<Map<String, dynamic>> getSessionHistory(String userId) async {
    try {
      // Try to get from API first
      return await SessionService.getSessionHistory(userId);
    } catch (e) {
      // If API fails, return local session info
      final localSession = await _sessionHiveService.getSession();
      if (localSession != null && localSession.userId == userId) {
        return {
          'success': true,
          'sessions': [
            {
              'loginAt': localSession.loginTime?.toIso8601String(),
              'logoutAt': localSession.isActive
                  ? null
                  : DateTime.now().toIso8601String(),
              'offline': true,
            }
          ],
          'offline': true,
        };
      }

      // No local data available
      return {
        'success': false,
        'sessions': [],
        'error': 'No session data available offline',
        'offline': true,
      };
    }
  }
}
