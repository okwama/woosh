import 'package:woosh/services/token_service.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';

class TokenDebugService {
  static const String _debugLogKey = 'token_debug_log';
  static const int _maxLogEntries = 50;

  /// Log a token-related event for debugging
  static Future<void> logEvent(String event,
      {Map<String, dynamic>? details}) async {
    final box = GetStorage();
    final logs = box.read<List<dynamic>>(_debugLogKey) ?? [];

    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'details': details ?? {},
      'hasAccessToken': TokenService.getAccessToken() != null,
      'hasRefreshToken': TokenService.getRefreshToken() != null,
      'isTokenExpired': TokenService.isTokenExpired(),
      'tokenExpiry': TokenService.getTokenExpiry()?.toIso8601String(),
    };

    logs.add(logEntry);

    // Keep only the last N entries
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }

    await box.write(_debugLogKey, logs);
    print('🔍 Token Debug: $event - ${details ?? {}}');
  }

  /// Get all debug logs
  static List<Map<String, dynamic>> getDebugLogs() {
    final box = GetStorage();
    final logs = box.read<List<dynamic>>(_debugLogKey) ?? [];
    return logs.map((log) => Map<String, dynamic>.from(log)).toList();
  }

  /// Clear debug logs
  static Future<void> clearDebugLogs() async {
    final box = GetStorage();
    await box.remove(_debugLogKey);
  }

  /// Get current token status
  static Map<String, dynamic> getCurrentTokenStatus() {
    final accessToken = TokenService.getAccessToken();
    final refreshToken = TokenService.getRefreshToken();
    final expiry = TokenService.getTokenExpiry();
    final isExpired = TokenService.isTokenExpired();
    final isExpiringSoon = TokenService.isTokenExpiringSoon();

    return {
      'hasAccessToken': accessToken != null,
      'hasRefreshToken': refreshToken != null,
      'accessTokenLength': accessToken?.length ?? 0,
      'refreshTokenLength': refreshToken?.length ?? 0,
      'isExpired': isExpired,
      'isExpiringSoon': isExpiringSoon,
      'expiryTime': expiry?.toIso8601String(),
      'timeUntilExpiry':
          expiry?.difference(DateTime.now()).inMinutes,
      'isAuthenticated': TokenService.isAuthenticated(),
    };
  }

  /// Log token refresh attempt
  static Future<void> logTokenRefreshAttempt(bool success,
      {String? error}) async {
    await logEvent('token_refresh_attempt', details: {
      'success': success,
      'error': error,
    });
  }

  /// Log logout event
  static Future<void> logLogout(String reason) async {
    await logEvent('logout', details: {
      'reason': reason,
    });
  }

  /// Log login event
  static Future<void> logLogin() async {
    await logEvent('login');
  }

  /// Log 401 error
  static Future<void> log401Error(String endpoint) async {
    await logEvent('401_error', details: {
      'endpoint': endpoint,
    });
  }

  /// Get debug summary
  static String getDebugSummary() {
    final logs = getDebugLogs();
    final status = getCurrentTokenStatus();

    final recentLogs = logs.length > 10 ? logs.sublist(logs.length - 10) : logs;
    final logoutCount = logs.where((log) => log['event'] == 'logout').length;
    final refreshCount =
        logs.where((log) => log['event'] == 'token_refresh_attempt').length;
    final refreshSuccessCount = logs
        .where((log) =>
            log['event'] == 'token_refresh_attempt' &&
            log['details']['success'] == true)
        .length;

    return '''
🔍 Token Debug Summary:
- Total log entries: ${logs.length}
- Logout events: $logoutCount
- Token refresh attempts: $refreshCount
- Successful refreshes: $refreshSuccessCount
- Current status: ${status['isAuthenticated'] ? 'Authenticated' : 'Not Authenticated'}
- Token expired: ${status['isExpired']}
- Expiring soon: ${status['isExpiringSoon']}
- Time until expiry: ${status['timeUntilExpiry']} minutes

Recent Events:
${recentLogs.map((log) => '- ${log['timestamp']}: ${log['event']}').join('\n')}
''';
  }
}
