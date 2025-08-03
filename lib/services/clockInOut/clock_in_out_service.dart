import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';

/// Clock In/Out Service - Simple and direct API calls
///
/// This service handles all clock in/out operations:
/// - Clock In: Start a new session
/// - Clock Out: End current session
/// - Get Status: Check current clock status
/// - Get History: Get today's sessions
class ClockInOutService {
  static const String baseUrl = '${Config.baseUrl}/clock-in-out';

  /// Get authentication headers
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

  /// Clock In - Start a new session
  static Future<Map<String, dynamic>> clockIn(String userId) async {
    try {
      print('🟢 Clock In: Starting session for user $userId');

      final now = DateTime.now();
      final formattedTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('$baseUrl/clock-in'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'userId': int.parse(userId),
          'clientTime': formattedTime,
        }),
      );

      print('🟢 Clock In: Response status: ${response.statusCode}');
      print('🟢 Clock In: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to clock in');
      }
    } catch (e) {
      print('❌ Clock In failed: $e');
      throw Exception('Failed to clock in: $e');
    }
  }

  /// Clock Out - End current session
  static Future<Map<String, dynamic>> clockOut(String userId) async {
    try {
      print('🔴 Clock Out: Ending session for user $userId');

      final now = DateTime.now();
      final formattedTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('$baseUrl/clock-out'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'userId': int.parse(userId),
          'clientTime': formattedTime,
        }),
      );

      print('🔴 Clock Out: Response status: ${response.statusCode}');
      print('🔴 Clock Out: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to clock out');
      }
    } catch (e) {
      print('❌ Clock Out failed: $e');
      throw Exception('Failed to clock out: $e');
    }
  }

  /// Get current clock status
  static Future<Map<String, dynamic>> getCurrentStatus(String userId) async {
    try {
      print('🔍 Get Status: Checking status for user $userId');

      final response = await http.get(
        Uri.parse('$baseUrl/status/$userId'),
        headers: await _getAuthHeaders(),
      );

      print('🔍 Get Status: Response status: ${response.statusCode}');
      print('🔍 Get Status: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get current status');
      }
    } catch (e) {
      print('❌ Get Status failed: $e');
      return {'isClockedIn': false};
    }
  }

  /// Get today's sessions
  static Future<Map<String, dynamic>> getTodaySessions(String userId) async {
    try {
      print('📅 Get Today Sessions: Getting sessions for user $userId');

      final response = await http.get(
        Uri.parse('$baseUrl/today/$userId'),
        headers: await _getAuthHeaders(),
      );

      print('📅 Get Today Sessions: Response status: ${response.statusCode}');
      print('📅 Get Today Sessions: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get today\'s sessions');
      }
    } catch (e) {
      print('❌ Get Today Sessions failed: $e');
      return {'sessions': []};
    }
  }

  /// Get clock history with optional date range
  static Future<Map<String, dynamic>> getClockHistory(
    String userId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      print('📅 Get Clock History: Getting history for user $userId');
      print('📅 Date range: $startDate to $endDate');

      String url = '$baseUrl/history/$userId';
      final queryParams = <String, String>{};

      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('📅 Get Clock History: Response status: ${response.statusCode}');
      print('📅 Get Clock History: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get clock history');
      }
    } catch (e) {
      print('❌ Get Clock History failed: $e');
      return {'sessions': []};
    }
  }

  /// Update user email
  static Future<Map<String, dynamic>> updateEmail(String newEmail) async {
    try {
      print('📧 Update Email: Updating email to $newEmail');

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/profile/email'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'email': newEmail,
        }),
      );

      print('📧 Update Email: Response status: ${response.statusCode}');
      print('📧 Update Email: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Email updated successfully: $newEmail');
        return data;
      } else {
        final errorData = json.decode(response.body);
        print('❌ Email update failed: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Failed to update email');
      }
    } catch (e) {
      print('❌ Update Email failed: $e');
      throw Exception('Failed to update email: $e');
    }
  }
}
