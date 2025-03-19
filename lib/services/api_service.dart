import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  static dynamic getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length > 1) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> decodedMap = json.decode(decoded);
        return decodedMap['userId']; // Return as dynamic to handle both int and String
      }
    } catch (e) {
      print('Error extracting userId from token: $e');
    }
    return null;
  }

  // Fetch Outlets
  static Future<List<Outlet>> fetchOutlets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Outlet.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load outlets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load outlets: $e');
    }
  }

  // Create a Journey Plan
  static Future<JourneyPlan> createJourneyPlan(int outletId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
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
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else {
        throw Exception('Failed to create journey plan: ${response.statusCode}');
      }
    } catch (e) {
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

      final response = await http.get(
        Uri.parse('$baseUrl/journey-plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (responseBody.containsKey('data') && responseBody['data'] is List) {
          final List<dynamic> journeyPlansJson = responseBody['data'];
          return journeyPlansJson.map((json) => JourneyPlan.fromJson(json)).toList();
        } else {
          throw Exception('Unexpected response format: missing data field or not a list');
        }
      } else {
        throw Exception('Failed to load journey plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('An error occurred while fetching journey plans: $e');
    }
  }

  // Update Journey Plan
  static Future<JourneyPlan> updateJourneyPlan({
    required int journeyId,
    required int outletId,
    String? status,
    DateTime? checkInTime,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

      final body = {
        'outletId': outletId,
        if (status != null) 'status': status,
        if (checkInTime != null) 'checkInTime': checkInTime.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      final response = await http.put(
        url,
        headers: _headers(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else {
        throw Exception('Failed to update journey plan: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('An error occurred while updating the journey plan: $e');
    }
  }

  // Upload Image
  static Future<String> uploadImage(File imageFile) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/upload-image');

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
        })
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedJson = jsonDecode(responseData);
        return decodedJson['imageUrl']; // Assuming the API returns the image URL
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('An error occurred while uploading the image: $e');
    }
  }

  // User Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
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

  // Helper Method: Common Headers
  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}