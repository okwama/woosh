import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/utils/auth_config.dart';




class ApiService {
  static String get baseUrl => '${ApiConfig.baseUrl}/api';

  // Helper to get auth token
  static String? _getAuthToken() {
    final box = GetStorage();
    return box.read("token");
  }

  // Helper to get user ID from token
  static String? getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length > 1) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> decodedMap = json.decode(decoded);
        return decodedMap['userId'];
      }
    } catch (e) {
      print('Error extracting userId from token: $e');
    }
    return null;
  }

  // Fetch Outlets
  static Future<List<Outlet>> fetchOutlets() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> outletsJson = jsonDecode(response.body);
        return outletsJson.map((json) => Outlet.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load outlets: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchOutlets: $e');
      throw Exception('An error occurred while fetching outlets: $e');
    }
  }

  // Create a Journey Plan
  static Future<JourneyPlan> createJourneyPlan(int outletId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final userId = getUserIdFromToken(token);
      if (userId == null) {
        throw Exception("User ID could not be determined");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'outletId': outletId,
        }),
      );

      if (response.statusCode == 201) {
        return JourneyPlan.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create journey plan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in createJourneyPlan: $e');
      throw Exception('An error occurred while creating the journey plan: $e');
    }
  }

  // Fetch Journey Plans
  static Future<List<JourneyPlan>> fetchJourneyPlans() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final userId = getUserIdFromToken(token);
      if (userId == null) {
        throw Exception("User ID could not be determined");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/journey-plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> journeyPlansJson = jsonDecode(response.body);
        return journeyPlansJson.map((json) => JourneyPlan.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load journey plans: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchJourneyPlans: $e');
      throw Exception('An error occurred while fetching journey plans: $e');
    }
  }

  // User Login
Future<Map<String, dynamic>> login(String email, String password) async {
  try {
    print('Attempting login for: $email');
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    print('Login response status: ${response.statusCode}');
    print('Login response body: ${response.body}');
    
    // Try to parse the response body
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      print('Error parsing response: $e');
      // If we can't parse the response, we'll handle it in the status code check
    }
    
    if (response.statusCode == 200) {
      final box = GetStorage();
      box.write('token', data['token']); 
      box.write('user', data['user']);
      return {
        'success': true,
        'token': data['token'],
        'user': data['user']
      };
    } else {
      // Use data['error'] if available, otherwise use a default message
      return {
        'success': false,
        'message': data['error'] ?? 'Login failed with status ${response.statusCode}'
      };
    }
  } catch (e) {
    print("Login Error: $e");
    if (e.toString().contains('XMLHttpRequest error')) {
      return {
        'success': false,
        'message': "Network error: Please check your internet connection and try again"
      };
    }
    return {
      'success': false,
      'message': "An error occurred while logging in: ${e.toString()}"
    };
  }
}

}