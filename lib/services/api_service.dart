import 'dart:convert';
import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:http_parser/http_parser.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/noticeboard_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/report/report_model.dart';
import 'package:whoosh/utils/auth_config.dart';
import 'package:whoosh/models/order_model.dart';
import 'package:whoosh/models/target_model.dart';
import 'package:whoosh/models/leave_model.dart';
import 'package:whoosh/controllers/auth_controller.dart';

// Handle platform-specific imports
import 'image_upload.dart';

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
  static const Duration tokenExpirationDuration = Duration(hours: 5);

  static String? _getAuthToken() {
    final box = GetStorage();
    final token = box.read('token');
    if (token != null) {
      print(
          'Token exists: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      // Check if token is expired
      if (_isTokenExpired(token)) {
        _handleTokenExpiration();
        return null;
      }
    } else {
      print('No authentication token found');
    }
    return token;
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length > 1) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> decodedMap = json.decode(decoded);
        final exp = decodedMap['exp'] as int;
        final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expirationTime);
      }
    } catch (e) {
      print('Error checking token expiration: $e');
    }
    return true;
  }

  static void _handleTokenExpiration() {
    logout();
  }

  static Future<void> logout() async {
    try {
      final box = GetStorage();
      await box.remove('token');
      await box.remove('user');
      final authController = Get.find<AuthController>();
      authController.isLoggedIn.value = false;
      print('Logged out successfully');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  static void handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('XMLHttpRequest error')) {
      Get.toNamed('/no_connection');
    }
  }

  static Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await logout();
      throw Exception("Session expired. Please log in again.");
    }
    return response;
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
          throw Exception("Connection timeout");
        },
      );

      final handledResponse = await _handleResponse(response);

      if (handledResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(handledResponse.body);
        return data.map((json) => Outlet.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load outlets: ${handledResponse.statusCode}');
      }
    } catch (e) {
      handleNetworkError(e);
      rethrow;
    }
  }

  // Create a Journey Plan
  static Future<JourneyPlan> createJourneyPlan(int outletId, DateTime dateTime,
      {String? notes}) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      // Format time as HH:MM:SS
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

      print(
          'Creating journey plan with outletId: $outletId, date: ${dateTime.toIso8601String()}, time: $time, notes: $notes');

      final Map<String, dynamic> requestBody = {
        'outletId': outletId,
        'date': dateTime.toIso8601String(),
        'time': time,
      };

      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: _headers(),
        body: jsonEncode(requestBody),
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
          throw Exception("Connection timeout");
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
    } on Exception catch (e) {
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
    String? notes,
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
        if (notes != null) 'notes': notes,
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

  // Upload Image function for cross-platform compatibility
  static Future<String> uploadImage(dynamic imageFile) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/upload-image');
      final authHeaders = _headers('multipart/form-data');

      // Create the multipart request
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll(authHeaders);

      // Use the platform-specific implementation to add file to request
      await addFileToRequest(request, imageFile, 'attachment');

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedJson = jsonDecode(responseData);
        return decodedJson['imageUrl']; // The backend returns the ImageKit URL
      } else {
        final responseData = await response.stream.bytesToString();
        print(
            'Upload failed with status: ${response.statusCode}, response: $responseData');
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload error: $e');
      throw Exception('An error occurred while uploading the image: $e');
    }
  }

  // User Login
  static Future<Map<String, dynamic>> login(
      String phoneNumber, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(),
        body: json.encode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Connection timeout");
        },
      );

      Map<String, dynamic> data = {};
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('Error parsing response: $e');
      }

      if (response.statusCode == 200) {
        final box = GetStorage();
        box.write('token', data['token']);
        box.write('user', data['user']);
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        return {
          'success': false,
          'message':
              data['error'] ?? 'Login failed with status ${response.statusCode}'
        };
      }
    } catch (e) {
      handleNetworkError(e);
      return {
        'success': false,
        'message': 'Network error: Please check your internet connection'
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

  // Get all targets for the authenticated user
  static Future<List<Target>> getTargets() async {
    try {
      // Check if API endpoint is available
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/targets'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => Target.fromJson(json)).toList();
        }
        // If the server returns 404, it means the endpoint doesn't exist yet
        else if (response.statusCode == 404) {
          print('Targets API endpoint not found, returning mock data');
          return _getMockTargets();
        } else {
          throw Exception('Failed to load targets: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // If timeout or connection error, return mock data
        print(
            'Connection error or timeout, returning mock data: $timeoutError');
        return _getMockTargets();
      }
    } catch (e) {
      print('Error fetching targets: $e');
      // Return mock data for development until backend is ready
      return _getMockTargets();
    }
  }

  // Mock data for targets - for development until backend is ready
  static List<Target> _getMockTargets() {
    final now = DateTime.now();
    final userId = int.tryParse(GetStorage().read('userId') ?? '1') ?? 1;

    return [
      Target(
        id: 1,
        title: 'Monthly Sales Target',
        description: 'Achieve monthly sales quota for Q2',
        type: TargetType.SALES,
        userId: userId,
        targetValue: 50000,
        currentValue: 32500,
        startDate: now.subtract(const Duration(days: 15)),
        endDate: now.add(const Duration(days: 15)),
        isCompleted: false,
      ),
      Target(
        id: 2,
        title: 'Store Visits',
        description: 'Complete assigned store visits',
        type: TargetType.VISITS,
        userId: userId,
        targetValue: 20,
        currentValue: 8,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 20)),
        isCompleted: false,
      ),
      Target(
        id: 3,
        title: 'Product Placements',
        description: 'Set up premium product displays',
        type: TargetType.PRODUCT_PLACEMENT,
        userId: userId,
        targetValue: 15,
        currentValue: 15,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 2)),
        isCompleted: true,
      ),
      Target(
        id: 4,
        title: 'New Client Acquisition',
        description: 'Bring onboard new retail clients',
        type: TargetType.CUSTOM,
        userId: userId,
        targetValue: 5,
        currentValue: 2,
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 60)),
        isCompleted: false,
      ),
      Target(
        id: 5,
        title: 'Last Quarter Performance',
        description: 'Q1 sales performance',
        type: TargetType.SALES,
        userId: userId,
        targetValue: 100000,
        currentValue: 85000,
        startDate: now.subtract(const Duration(days: 90)),
        endDate: now.subtract(const Duration(days: 30)),
        isCompleted: false,
      ),
    ];
  }

  // Create a new target
  static Future<Target> createTarget(Target target) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/targets'),
              headers: _headers(),
              body: jsonEncode(target.toJson()),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception('Failed to create target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock response for development
        print(
            'Connection error or timeout, returning mock response: $timeoutError');
        return target.copyWith(id: DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      print('Error creating target: $e');
      // Return mock response for development
      return target.copyWith(id: DateTime.now().millisecondsSinceEpoch);
    }
  }

  // Update an existing target
  static Future<Target> updateTarget(Target target) async {
    try {
      if (target.id == null) {
        throw Exception('Target ID is required for update');
      }

      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/targets/${target.id}'),
              headers: _headers(),
              body: jsonEncode(target.toJson()),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception('Failed to update target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock response for development
        print(
            'Connection error or timeout, returning mock response: $timeoutError');
        return target;
      }
    } catch (e) {
      print('Error updating target: $e');
      // For development, return the target instead of throwing
      return target;
    }
  }

  // Delete a target
  static Future<bool> deleteTarget(int targetId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .delete(
              Uri.parse('$baseUrl/targets/$targetId'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return true;
        } else {
          throw Exception('Failed to delete target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock success for development
        print(
            'Connection error or timeout, returning mock success: $timeoutError');
        return true;
      }
    } catch (e) {
      print('Error deleting target: $e');
      // For development, return success instead of throwing
      return true;
    }
  }

  // Update target progress
  static Future<Target> updateTargetProgress(int targetId, int newValue) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .patch(
              Uri.parse('$baseUrl/targets/$targetId/progress'),
              headers: _headers(),
              body: jsonEncode({'currentValue': newValue}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception(
              'Failed to update target progress: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Mock updating a target's progress
        print(
            'Connection error or timeout, returning mock data: $timeoutError');
        // For development, create a mock updated target
        final mockTargets = _getMockTargets();
        final targetIndex = mockTargets.indexWhere((t) => t.id == targetId);
        if (targetIndex != -1) {
          final updatedTarget =
              mockTargets[targetIndex].copyWith(currentValue: newValue);
          return updatedTarget;
        } else {
          // If target not found in mock data, create a new one with the updated progress
          return Target(
            id: targetId,
            title: 'Mock Target',
            description: 'Mock target created for development',
            type: TargetType.CUSTOM,
            userId: int.tryParse(GetStorage().read('userId') ?? '1') ?? 1,
            targetValue: newValue * 2, // Just a simple mock value
            currentValue: newValue,
            startDate: DateTime.now().subtract(const Duration(days: 10)),
            endDate: DateTime.now().add(const Duration(days: 20)),
            isCompleted: false,
          );
        }
      }
    } catch (e) {
      print('Error updating target progress: $e');
      // For development, create a mock updated target
      return Target(
        id: targetId,
        title: 'Mock Target',
        description: 'Mock target created from error handling',
        type: TargetType.CUSTOM,
        userId: int.tryParse(GetStorage().read('userId') ?? '1') ?? 1,
        targetValue: newValue * 2, // Just a simple mock value
        currentValue: newValue,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        isCompleted: false,
      );
    }
  }

  static Future<Leave> submitLeaveApplication({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    dynamic attachmentFile, // Accepts File for mobile, Uint8List for web
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      print('Submitting leave application with data:');
      print('leaveType: $leaveType');
      print('startDate: $startDate');
      print('endDate: $endDate');
      print('reason: $reason');
      print('attachment: ${attachmentFile != null ? "Yes" : "No file"}');

      final uri = Uri.parse('$baseUrl/leave');

      // Handle request when no attachment is present
      if (attachmentFile == null) {
        final response = await http.post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'leaveType': leaveType,
            'startDate': startDate,
            'endDate': endDate,
            'reason': reason,
          }),
        );

        if (response.statusCode == 201) {
          return Leave.fromJson(jsonDecode(response.body));
        } else {
          throw Exception(jsonDecode(response.body)['error'] ??
              'Failed to submit leave application');
        }
      } else {
        // Handle Multipart File Upload
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          })
          ..fields['leaveType'] = leaveType
          ..fields['startDate'] = startDate
          ..fields['endDate'] = endDate
          ..fields['reason'] = reason;

        // Handle different file types based on platform
        if (kIsWeb) {
          print('Web file upload: Adding bytes to multipart request');
          // Web file upload (bytes)
          request.files.add(http.MultipartFile.fromBytes(
            'attachment',
            attachmentFile,
            filename:
                'web_document_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: MediaType('application', 'octet-stream'),
          ));
        } else {
          print('Mobile file upload: Adding file from path');
          // Mobile/desktop file upload (File object)
          request.files.add(await http.MultipartFile.fromPath(
            'attachment',
            attachmentFile.path,
            filename: attachmentFile.path.split('/').last,
          ));
        }

        print('Sending multipart request for leave application');
        final streamedResponse = await request.send();
        print('Response status code: ${streamedResponse.statusCode}');

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 201) {
          return Leave.fromJson(jsonDecode(response.body));
        } else {
          print('Leave application failed: ${response.body}');
          throw Exception(jsonDecode(response.body)['error'] ??
              'Failed to submit leave application');
        }
      }
    } catch (e) {
      print('Error in submitLeaveApplication: $e');
      rethrow;
    }
  }

  // Get user's leave applications
  static Future<List<Leave>> getUserLeaves() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave/my-leaves'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Leave.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch leave applications');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get all leave applications (admin only)
  static Future<List<Leave>> getAllLeaves() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave/all'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Leave.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch all leave applications');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update leave status (admin only)
  static Future<Leave> updateLeaveStatus(
      int leaveId, LeaveStatus status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/leave/$leaveId/status'),
        headers: _headers(),
        body: jsonEncode({'status': status.toString().split('.').last}),
      );

      if (response.statusCode == 200) {
        return Leave.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update leave status');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fix for SocketException catch blocks
  static Future<List<Outlet>> fetchOutletsByGeolocation(
      double latitude, double longitude) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse(
            '$baseUrl/outlets/nearby?latitude=$latitude&longitude=$longitude'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Outlet.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch outlets by geolocation: ${response.statusCode}');
      }
    } on Exception catch (e) {
      print('Error fetching outlets by geolocation: $e');
      handleNetworkError(e);
      throw Exception('Failed to fetch outlets by geolocation: $e');
    }
  }

  // Fix for File type check
  static bool _isValidFileAttachment(dynamic file) {
    return file != null;
  }

  static Future<void> updateOrderStatus(
      int orderId, String status, String? reason) async {
    try {
      // ... existing code
    } on Exception catch (e) {
      print('Error updating order status: $e');
      handleNetworkError(e);
      throw Exception('Failed to update order status: $e');
    }
  }
}
