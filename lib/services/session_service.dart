import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';

class SessionService {
  static const String baseUrl = '${Config.baseUrl}/api';

  static Future<Map<String, String>> _getAuthHeaders() async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _updateToken(http.Response response) {
    final newToken = response.headers['x-new-token'];
    if (newToken != null) {
      GetStorage().write('token', newToken);
    }
  }

  static Future<Map<String, dynamic>> recordLogin(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions/login'),
        headers: {
          'Content-Type': 'application/json',
          'timezone': 'Africa/Nairobi', // Set default timezone to GMT+3
        },
        body: json.encode({'userId': userId}),
      );

      _updateToken(response);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to record login: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error recording login: $e');
    }
  }

  static Future<Map<String, dynamic>> recordLogout(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions/logout'),
        headers: {
          'Content-Type': 'application/json',
          'timezone': 'Africa/Nairobi', // Set default timezone to GMT+3
          ...await _getAuthHeaders(),
        },
        body: json.encode({'userId': userId}),
      );

      _updateToken(response);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to record logout: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error recording logout: $e');
    }
  }

  static Future<Map<String, dynamic>> getSessionHistory(
    String userId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final url = '$baseUrl/sessions/history/$userId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...await _getAuthHeaders(),
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      _updateToken(response);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Store the successful response in GetStorage for future 304 responses
        final box = GetStorage();
        box.write('last_sessions_$userId', data);
        return data;
      } else if (response.statusCode == 304) {
        // Get the last known sessions from storage
        final box = GetStorage();
        final lastKnownData = box.read('last_sessions_$userId');
        return lastKnownData ?? {'sessions': []};
      } else {
        throw Exception('Failed to fetch session history: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching session history: $e');
    }
  }
}
