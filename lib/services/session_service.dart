import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';

/// Session Service with reliable status-based session detection
///
/// This service uses the backend's status field to determine active sessions:
/// - Status "1" = Active session (user logged in)
/// - Status "2" = Ended session (user logged out)
///
/// This approach is more reliable than checking logoutAt field because:
/// 1. Status is explicitly set by the backend
/// 2. No ambiguity with null values
/// 3. Clear state management
/// 4. Consistent across all session operations
class SessionService {
  static const String baseUrl = '${Config.baseUrl}/api';

  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
    };

    // Check if token is expired and refresh if needed
    if (TokenService.isTokenExpired()) {
      final refreshed = await ApiService.refreshAccessToken();
      if (!refreshed) {
        throw Exception('Authentication required');
      }
    }

    final accessToken = TokenService.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  static void _updateToken(http.Response response) {
    final newToken = response.headers['x-new-token'];
    if (newToken != null) {
      // Update the access token in TokenService
      final refreshToken = TokenService.getRefreshToken();
      if (refreshToken != null) {
        TokenService.storeTokens(
          accessToken: newToken,
          refreshToken: refreshToken,
        );
      }
    }
  }

  static Future<Map<String, dynamic>> recordLogin(String userId) async {
    try {
      final now = DateTime.now();
      print('Debug - Current time: ${now.toIso8601String()}');
      print('Debug - Timezone: Africa/Nairobi (GMT+3)');

      final response = await http.post(
        Uri.parse('$baseUrl/sessions/login'),
        headers: {
          'Content-Type': 'application/json',
          'timezone': 'Africa/Nairobi', // Set default timezone to GMT+3
          ...await _getAuthHeaders(),
        },
        body: json.encode({
          'userId': userId,
          'clientTime': now.toIso8601String(),
        }),
      );

      _updateToken(response);

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print(
            'Debug - Server response time: ${responseData['loginAt'] ?? 'Not provided'}');
        return responseData;
      } else {
        print('Debug - Error response: ${response.body}');
        throw Exception('Failed to record login: ${response.body}');
      }
    } catch (e) {
      print('Debug - Exception: $e');
      throw Exception('Error recording login: $e');
    }
  }

  static Future<Map<String, dynamic>> recordLogout(String userId) async {
    try {
      final now = DateTime.now();
      print('Debug - Logout - Current time: ${now.toIso8601String()}');
      print('Debug - Logout - Timezone: Africa/Nairobi (GMT+3)');

      final response = await http.post(
        Uri.parse('$baseUrl/sessions/logout'),
        headers: {
          'Content-Type': 'application/json',
          'timezone': 'Africa/Nairobi', // Set default timezone to GMT+3
          ...await _getAuthHeaders(),
        },
        body: json.encode({
          'userId': userId,
          'clientTime': now.toIso8601String(),
        }),
      );

      _updateToken(response);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print(
            'Debug - Logout - Server response time: ${responseData['logoutAt'] ?? 'Not provided'}');
        return responseData;
      } else {
        print('Debug - Logout - Error response: ${response.body}');
        throw Exception('Failed to record logout: ${response.body}');
      }
    } catch (e) {
      print('Debug - Logout - Exception: $e');
      throw Exception('Error recording logout: $e');
    }
  }

  static Future<Map<String, dynamic>> getSessionHistory(
    String userId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      var url = '$baseUrl/sessions/history/$userId';

      // Add query parameters if dates are provided
      if (startDate != null || endDate != null) {
        final queryParams = <String, String>{};
        if (startDate != null) queryParams['startDate'] = startDate;
        if (endDate != null) queryParams['endDate'] = endDate;

        final uri = Uri.parse(url).replace(queryParameters: queryParams);
        url = uri.toString();
      }

      print('Debug - Fetching sessions with URL: $url');
      print('Debug - Date range: startDate=$startDate, endDate=$endDate');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...await _getAuthHeaders(),
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Expires': '0',
          'timezone': 'Africa/Nairobi',
        },
      );

      _updateToken(response);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Process sessions to ensure sessionStart and sessionEnd are properly handled
        if (data['sessions'] != null) {
          final sessions = data['sessions'] as List;
          for (var session in sessions) {
            // If sessionStart is not provided, use loginAt
            if (session['sessionStart'] == null && session['loginAt'] != null) {
              session['sessionStart'] = session['loginAt'];
            }
            // If sessionEnd is not provided, use logoutAt
            if (session['sessionEnd'] == null && session['logoutAt'] != null) {
              session['sessionEnd'] = session['logoutAt'];
            }
          }
        }

        // Store the processed response in GetStorage
        final box = GetStorage();
        final cacheKey =
            'last_sessions_${userId}_${startDate ?? 'all'}_${endDate ?? 'all'}';
        box.write(cacheKey, data);

        print('Debug - Processed sessions: ${data['sessions']?.length ?? 0}');
        return data;
      } else if (response.statusCode == 304) {
        // Get the last known sessions from storage
        final box = GetStorage();
        final cacheKey =
            'last_sessions_${userId}_${startDate ?? 'all'}_${endDate ?? 'all'}';
        final lastKnownData = box.read(cacheKey);
        return lastKnownData ?? {'sessions': []};
      } else {
        print('Debug - Error response: ${response.body}');
        // Return cached data instead of throwing error
        final box = GetStorage();
        final cacheKey =
            'last_sessions_${userId}_${startDate ?? 'all'}_${endDate ?? 'all'}';
        final cachedData = box.read(cacheKey);
        if (cachedData != null) {
          print('Debug - Returning cached data due to API error');
          return cachedData;
        }
        return {'sessions': []};
      }
    } catch (e) {
      print('Debug - Exception: $e');
      // Return cached data instead of throwing error
      final box = GetStorage();
      final cacheKey =
          'last_sessions_${userId}_${startDate ?? 'all'}_${endDate ?? 'all'}';
      final cachedData = box.read(cacheKey);
      if (cachedData != null) {
        print('Debug - Returning cached data due to network error');
        return cachedData;
      }
      return {'sessions': []};
    }
  }

  static Future<bool> isSessionValid(String userId) async {
    try {
      final response = await getSessionHistory(userId);
      final sessions = response['sessions'] as List;
      if (sessions.isNotEmpty) {
        final lastSession = sessions.first;
        // Use status field instead of logoutAt for more reliable session detection
        // Status "1" = Active session, Status "2" = Ended session
        final isActive = lastSession['status'] == '1';

        if (isActive) {
          // Check if session is within shift hours (9-hour shift)
          final loginAt = DateTime.parse(lastSession['loginAt']);
          final now = DateTime.now();
          return now.difference(loginAt).inHours < 9;
        }
      }
      return false;
    } catch (e) {
      print('Error checking session validity: $e');
      return false;
    }
  }

  /// Get current session status using the reliable status field
  static Future<bool> getCurrentSessionStatus(String userId) async {
    try {
      print('🔍 API: Getting session history for user $userId');
      final response = await getSessionHistory(userId);
      final sessions = response['sessions'] as List;
      print('🔍 API: Found ${sessions.length} sessions');

      if (sessions.isNotEmpty) {
        final lastSession = sessions.first;
        final status = lastSession['status'] as String?;
        final logoutAt = lastSession['logoutAt'];

        print('🔍 API: Last session status = $status');
        print('🔍 API: Last session loginAt = ${lastSession['loginAt']}');
        print('🔍 API: Last session logoutAt = $logoutAt');

        // Use raw status codes for reliable session detection
        // Status "1" = Active session, Status "2" = Ended session
        final isActive = status == '1';
        print('🔍 API: Session active = $isActive');
        return isActive;
      }

      print('🔍 API: No sessions found, returning false');
      return false;
    } catch (e) {
      print('❌ API: Error getting current session status: $e');
      return false;
    }
  }

  /// Check if session is active using status field (simplified version)
  static Future<bool> isSessionActive(String userId) async {
    return await getCurrentSessionStatus(userId);
  }

  /// Get session status with detailed information
  static Future<Map<String, dynamic>> getSessionStatus(String userId) async {
    try {
      final response = await getSessionHistory(userId);
      final sessions = response['sessions'] as List;

      if (sessions.isNotEmpty) {
        final lastSession = sessions.first;
        final status = lastSession['status'] as String?;
        final isActive = status == '1';

        return {
          'isActive': isActive,
          'status': status,
          'loginAt': lastSession['loginAt'],
          'logoutAt': lastSession['logoutAt'],
          'sessionStart': lastSession['sessionStart'],
          'sessionEnd': lastSession['sessionEnd'],
          'duration': lastSession['duration'],
          'isLate': lastSession['isLate'],
          'isEarly': lastSession['isEarly'],
        };
      }

      return {
        'isActive': false,
        'status': null,
        'loginAt': null,
        'logoutAt': null,
        'sessionStart': null,
        'sessionEnd': null,
        'duration': null,
        'isLate': null,
        'isEarly': null,
      };
    } catch (e) {
      print('Error getting session status: $e');
      return {
        'isActive': false,
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  static Future<void> checkSessionTimeout() async {
    final box = GetStorage();
    final userId = box.read<String>('userId');
    if (userId != null) {
      final isValid = await isSessionValid(userId);
      if (!isValid) {
        await recordLogout(userId);
        box.write('isSessionActive', false);
      }
    }
  }
}
