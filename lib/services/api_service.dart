import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/noticeboard_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/utils/auth_config.dart';
import 'package:flutter/foundation.dart';

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
        return decodedMap[
            'userId']; // Return as dynamic to handle both int and String
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
  static Future<JourneyPlan> createJourneyPlan(
      int outletId, DateTime dateTime) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      // Format time as HH:MM:SS
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

      print(
          'Creating journey plan with outletId: $outletId, date: ${dateTime.toIso8601String()}, time: $time');

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: _headers(token),
        body: jsonEncode({
          'outletId': outletId,
          'date': dateTime.toIso8601String(),
          'time': time,
        }),
      );

      print('Create journey plan response status: ${response.statusCode}');
      print('Create journey plan response body: ${response.body}');

      if (response.statusCode == 201) {
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to create journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
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

      print('Fetching journey plans with token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/journey-plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Journey plans response status: ${response.statusCode}');
      print('Journey plans response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (responseBody.containsKey('data') && responseBody['data'] is List) {
          final List<dynamic> journeyPlansJson = responseBody['data'];
          return journeyPlansJson
              .map((json) => JourneyPlan.fromJson(json))
              .toList();
        } else {
          throw Exception(
              'Unexpected response format: missing data field or not a list');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to load journey plans: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error in fetchJourneyPlans: $e');
      throw Exception('An error occurred while fetching journey plans: $e');
    }
  }

  // Check Journey Plan Status
  static Future<bool> isJourneyPlanCheckedIn(int journeyId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/journey-plans/$journeyId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final journeyPlan = JourneyPlan.fromJson(jsonDecode(response.body));
        return journeyPlan.status == JourneyPlan.STATUS_CHECKED_IN;
      } else {
        throw Exception(
            'Failed to check journey plan status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking journey plan status: $e');
      throw Exception('Failed to check journey plan status: $e');
    }
  }

  // Update Journey Plan
  static Future<JourneyPlan> updateJourneyPlan({
    required int journeyId,
    required int outletId,
    int? status,
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

      // Validate status value if provided
      if (status != null &&
          status != JourneyPlan.STATUS_PENDING &&
          status != JourneyPlan.STATUS_CHECKED_IN) {
        throw Exception('Invalid status value: $status');
      }

      final body = {
        'outletId': outletId,
        if (status != null) 'status': status,
        if (checkInTime != null) 'checkInTime': checkInTime.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      print('Updating journey plan with body: $body');

      final response = await http.put(
        url,
        headers: _headers(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else {
        throw Exception(
            'Failed to update journey plan: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('An error occurred while updating the journey plan: $e');
    }
  }

  static Future<List<NoticeBoard>> getNotice() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      print('Fetching notices from: $baseUrl/notice-board');
      print(
          'Using token: ${token.substring(0, 20)}...'); // Only print first 20 chars for security

      final response = await http.get(
        Uri.parse('$baseUrl/notice-board'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Notice board response status: ${response.statusCode}');
      print('Notice board response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return []; // Return empty list instead of throwing an error
        }

        try {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => NoticeBoard.fromJson(json)).toList();
        } catch (e) {
          print('Error parsing notice board response: $e');
          throw Exception('Failed to parse notice board data: $e');
        }
      } else {
        throw Exception(
            'Failed to fetch notices. Server responded with ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getNotice: $e');
      throw Exception('Error fetching notices: ${e.toString()}');
    }
  }

  // Upload Image
  static Future<String> uploadImage(dynamic imageData) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      print('Starting image upload...');
      final url = Uri.parse('$baseUrl/upload-image');

      // Create multipart request
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        });

      // Add the file to the request
      try {
        if (imageData is Uint8List) {
          // For web platforms (using bytes)
          print('Processing web image upload...');
          print('Image bytes length: ${imageData.length}');
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            imageData,
            filename: 'image.jpg',
          ));
        } else if (imageData is File) {
          // For mobile platforms (using File)
          print('Processing mobile image upload...');
          if (!imageData.existsSync()) {
            throw Exception('Image file does not exist: ${imageData.path}');
          }
          request.files
              .add(await http.MultipartFile.fromPath('file', imageData.path));
        } else {
          throw Exception(
              'Unsupported image data type: ${imageData.runtimeType}');
        }
      } catch (e) {
        print('Error preparing image for upload: $e');
        throw Exception('Failed to prepare image for upload: $e');
      }

      print('Sending upload request...');
      final response = await request.send();
      print('Upload response status: ${response.statusCode}');

      final responseData = await response.stream.bytesToString();
      print('Upload response data: $responseData');

      final decodedJson = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final imageUrl = decodedJson['imageUrl'];
        if (imageUrl == null) {
          throw Exception('No image URL in response');
        }
        print('Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        final errorMessage = decodedJson['error'] ?? 'Unknown error';
        throw Exception(
            'Failed to upload image: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      print('Error in uploadImage: $e');
      throw Exception('An error occurred while uploading the image: $e');
    }
  }

  // User Login
  static Future<Map<String, dynamic>> login(
      String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'password': password}),
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
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        // Use data['error'] if available, otherwise use a default message
        return {
          'success': false,
          'message':
              data['error'] ?? 'Login failed with status ${response.statusCode}'
        };
      }
    } catch (e) {
      print("Login Error: $e");
      if (e.toString().contains('XMLHttpRequest error')) {
        return {
          'success': false,
          'message':
              "Network error: Please check your internet connection and try again"
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
        'Accept': 'application/json',
      };
}
