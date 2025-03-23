import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/noticeboard_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/report/report_model.dart';
import 'package:whoosh/models/report/productReport_model.dart';
import 'package:whoosh/models/report/visibilityReport_model.dart';
import 'package:whoosh/models/report/feedbackReport_model.dart';
import 'package:whoosh/utils/auth_config.dart';
import 'package:whoosh/models/order_model.dart';

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class ApiService {
  static const String baseUrl = '${ApiConfig.baseUrl}/api';

  static String? _getAuthToken() {
    final box = GetStorage();
    final token = box.read('token');
    if (token != null) {
      print(
          'Token exists: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    } else {
      print('No authentication token found');
    }
    return token;
  }

  static Map<String, String> _headers([String? additionalContentType]) {
    final token = _getAuthToken();
    return {
      'Content-Type': additionalContentType ?? 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http
          .get(
        Uri.parse('$baseUrl/outlets'),
        headers: _headers(),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
              "Connection timeout. Check your internet connection and server availability.");
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Outlet.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized: Please log in again");
      } else {
        throw Exception('Failed to load outlets: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('Network error in fetchOutlets: $e');
      throw Exception(
          "Network error: Could not connect to the server. Please check your internet connection and ensure the server is running.");
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
        headers: _headers(),
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

      print(
          'Fetching journey plans with token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

      final response = await http
          .get(
        Uri.parse('$baseUrl/journey-plans'),
        headers: _headers(),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
              "Connection timeout. Check your internet connection and server availability.");
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
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized: Please log in again");
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to load journey plans: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } on SocketException catch (e) {
      print('Network error in fetchJourneyPlans: $e');
      throw Exception(
          "Network error: Could not connect to the server. Please check your internet connection and ensure the server is running.");
    } catch (e) {
      print('Error in fetchJourneyPlans: $e');
      throw Exception('An error occurred while fetching journey plans: $e');
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

      // Convert numeric status to string status for the API
      String? statusString;
      if (status != null) {
        switch (status) {
          case JourneyPlan.statusPending:
            statusString = 'pending';
            break;
          case JourneyPlan.statusCheckedIn:
            statusString = 'checked_in';
            break;
          case JourneyPlan.statusInProgress:
            statusString = 'in_progress';
            break;
          case JourneyPlan.statusCompleted:
            statusString = 'completed';
            break;
          case JourneyPlan.statusCancelled:
            statusString = 'cancelled';
            break;
          default:
            throw Exception('Invalid status value: $status');
        }
      }

      final body = {
        'outletId': outletId,
        if (statusString != null) 'status': statusString,
        if (checkInTime != null) 'checkInTime': checkInTime.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      final response = await http.put(
        url,
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to update journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('An error occurred while updating the journey plan: $e');
    }
  }

  // Get Journey Plan by ID
  static Future<JourneyPlan?> getJourneyPlanById(int journeyId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

      final response = await http.get(
        url,
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        return JourneyPlan.fromJson(decodedJson);
      } else if (response.statusCode == 404) {
        return null; // Journey plan not found
      } else {
        throw Exception('Failed to fetch journey plan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getJourneyPlanById: $e');
      throw Exception('An error occurred while fetching the journey plan: $e');
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
          'Using token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/notice-board'),
        headers: _headers(),
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
  static Future<String> uploadImage(File imageFile) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/upload-image');

      // Since we're uploading files, we need to set a specific content type
      final authHeaders = _headers('multipart/form-data');

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll(authHeaders)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedJson = jsonDecode(responseData);
        return decodedJson[
            'imageUrl']; // Assuming the API returns the image URL
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
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

  // Get products (independent of outlets)
  static Future<List<Product>> getProducts() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          return data.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to load products');
    }
  }

  Future<Report> submitReport(Report report) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: _headers(),
        body: jsonEncode(report.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Report.fromJson(data);
      } else {
        throw Exception('Failed to submit report: ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting report: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  Future<List<Report>> getReports({
    int? journeyPlanId,
    int? outletId,
    int? userId,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (journeyPlanId != null)
        queryParams['journeyPlanId'] = journeyPlanId.toString();
      if (outletId != null) queryParams['outletId'] = outletId.toString();
      if (userId != null) queryParams['userId'] = userId.toString();

      final uri =
          Uri.parse('$baseUrl/reports').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Report.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reports: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching reports: $e');
      throw Exception('Failed to load reports: $e');
    }
  }

  // Get orders with pagination
  static Future<PaginatedResponse<Order>> getOrders({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/orders?page=$page&limit=$limit'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          return PaginatedResponse<Order>(
            data: data.map((json) => Order.fromJson(json)).toList(),
            total: responseData['total'],
            page: responseData['page'],
            limit: responseData['limit'],
            totalPages: responseData['totalPages'],
          );
        } else {
          throw Exception(responseData['error'] ?? 'Failed to load orders');
        }
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      throw Exception('Failed to load orders');
    }
  }

  // Create a new order
  static Future<Order> createOrder({
    required int outletId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _headers(),
        body: jsonEncode({
          'outletId': outletId,
          'productId': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Order.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to create order');
        }
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating order: $e');
      throw Exception('Failed to create order');
    }
  }

  // Update an existing order
  static Future<Order> updateOrder({
    required int orderId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: _headers(),
        body: jsonEncode({
          'productId': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Order.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to update order');
        }
      } else {
        throw Exception('Failed to update order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating order: $e');
      throw Exception('Failed to update order');
    }
  }

  // Check if the user is authenticated
  static bool isAuthenticated() {
    final token = _getAuthToken();
    return token != null;
  }
}
