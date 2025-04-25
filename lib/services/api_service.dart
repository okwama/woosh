import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart'
    hide FormData, MultipartFile; // Hide conflicting imports
import 'package:http_parser/http_parser.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/noticeboard_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/target_model.dart';
import 'package:woosh/models/leave_model.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:woosh/services/target_service.dart';
import 'package:woosh/models/client_model.dart';

// Handle platform-specific imports
import 'image_upload.dart';

// API Caching System
class ApiCache {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration cacheValidity = Duration(minutes: 5);

  static void set(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamp[key] = DateTime.now();
  }

  static dynamic get(String key) {
    if (!_cache.containsKey(key)) return null;
    if (DateTime.now().difference(_cacheTimestamp[key]!) > cacheValidity) {
      _cache.remove(key);
      _cacheTimestamp.remove(key);
      return null;
    }
    return _cache[key];
  }

  static void clear() {
    _cache.clear();
    _cacheTimestamp.clear();
  }
}

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
  static const String baseUrl = '${Config.baseUrl}/api';
  static const Duration tokenExpirationDuration = Duration(hours: 5);

  static String? _getAuthToken() {
    final box = GetStorage();
    return box.read<String>('token');
  }

  static Future<Map<String, String>> _headers(
      [String? additionalContentType]) async {
    final token = _getAuthToken();
    return {
      'Content-Type': additionalContentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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

  // Fetch Clients (replaces fetchOutlets)
  static Future<List<Client>> fetchClients() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http
          .get(
        Uri.parse(
            '$baseUrl/outlets'), // Keep using /outlets endpoint until backend is updated
        headers: await _headers(),
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
        return data.map((json) {
          final outlet = Outlet.fromJson(json);
          return Client(
            id: outlet.id,
            name: outlet.name,
            address: outlet.address,
            balance: outlet.balance,
            latitude: outlet.latitude,
            longitude: outlet.longitude,
            email: outlet.email,
            contact: outlet.contact,
            taxPin: outlet.taxPin,
            location: outlet.location,
            clientType: outlet.clientType,
            regionId: outlet.regionId ?? 0,
            region: outlet.region ?? '',
            countryId: outlet.countryId ?? 0,
          );
        }).toList();
      } else {
        throw Exception(
            'Failed to load clients: ${handledResponse.statusCode}');
      }
    } catch (e) {
      handleNetworkError(e);
      rethrow;
    }
  }

  // Keep fetchOutlets for backward compatibility
  @Deprecated('Use fetchClients() instead')
  static Future<List<Outlet>> fetchOutlets() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http
          .get(
        Uri.parse('$baseUrl/outlets'),
        headers: await _headers(),
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
  static Future<JourneyPlan> createJourneyPlan(int clientId, DateTime dateTime,
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
          'Creating journey plan with clientId: $clientId, date: ${dateTime.toIso8601String()}, time: $time, notes: $notes');

      final Map<String, dynamic> requestBody = {
        'clientId': clientId,
        'date': dateTime.toIso8601String(),
        'time': time,
      };

      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      // Add debug logging
      print('Journey plan request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: await _headers(),
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
        headers: await _headers(),
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
    required int clientId,
    int? status,
    DateTime? checkInTime,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? notes,
    DateTime? checkoutTime,
    double? checkoutLatitude,
    double? checkoutLongitude,
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
        'clientId': clientId,
        if (statusString != null) 'status': statusString,
        if (checkInTime != null) 'checkInTime': checkInTime.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (notes != null) 'notes': notes,
        if (checkoutTime != null)
          'checkoutTime': checkoutTime.toIso8601String(),
        if (checkoutLatitude != null) 'checkoutLatitude': checkoutLatitude,
        if (checkoutLongitude != null) 'checkoutLongitude': checkoutLongitude,
      };

      // Log all API requests for debugging
      print('API REQUEST - JOURNEY PLAN UPDATE:');
      print('URL: $url');
      print('Journey ID: $journeyId');
      print('Client ID: $clientId');
      print('Status: $statusString');
      print('Request Body: ${jsonEncode(body)}');

      final response = await http.put(
        url,
        headers: await _headers(),
        body: jsonEncode(body),
      );

      // Log all responses
      print('API RESPONSE - JOURNEY PLAN UPDATE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);

        // Log successful response data
        if (checkoutTime != null) {
          print('CHECKOUT API - RESPONSE SUCCESSFUL:');
          print('Journey ID: ${decodedJson['id']}');
          print('Status: ${decodedJson['status']}');
          print('Checkout Time: ${decodedJson['checkoutTime']}');
          print('Checkout Latitude: ${decodedJson['checkoutLatitude']}');
          print('Checkout Longitude: ${decodedJson['checkoutLongitude']}');
        }

        return JourneyPlan.fromJson(decodedJson);
      } else {
        final errorBody = jsonDecode(response.body);

        // Log error response data
        if (checkoutTime != null) {
          print('CHECKOUT API - RESPONSE ERROR:');
          print('Status Code: ${response.statusCode}');
          print('Error Message: ${errorBody['error'] ?? 'Unknown error'}');
        }

        throw Exception(
            'Failed to update journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Log exception
      if (checkoutTime != null) {
        print('CHECKOUT API - EXCEPTION:');
        print('Error: $e');
      }

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
        headers: await _headers(),
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
        headers: await _headers(),
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
      final authHeaders = await _headers('multipart/form-data');

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
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final box = GetStorage();
        box.write('token', data['token']);
        box.write('salesRep', data['salesRep']);
        return {
          'success': true,
          'token': data['token'],
          'salesRep': data['salesRep']
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'error': 'Network error occurred',
      };
    }
  }

  // Register new user
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'salesRep': data['data']['salesRep'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Registration failed',
          'details': error['details'],
        };
      }
    } catch (e) {
      print('Registration error: $e');
      return {
        'success': false,
        'error': 'Network error occurred',
      };
    }
  }

  // Get products (independent of outlets)
  static Future<List<Product>> getProducts() async {
    try {
      print('[Products] Fetching products from API');
      final response = await http.get(
        Uri.parse('$baseUrl${Config.productsEndpoint}'),
        headers: await _headers(),
      );

      print('[Products] Response status: ${response.statusCode}');
      print('[Products] Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to load products: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      if (!responseData.containsKey('data')) {
        throw Exception('Invalid API response: missing data field');
      }

      // Cache the response
      ApiCache.set('products', responseData['data']);

      final products = (responseData['data'] as List)
          .map((item) => Product.fromJson(item))
          .toList();

      print('[Products] Successfully loaded ${products.length} products');

      // Pre-cache images safely
      if (Get.context != null) {
        for (var product in products) {
          if (product.imageUrl?.isNotEmpty ?? false) {
            try {
              final imageProvider = NetworkImage(product.imageUrl!);
              precacheImage(imageProvider, Get.context!);
            } catch (e) {
              print(
                  '[Products] Failed to precache image for product ${product.id}: $e');
              // Continue with next product even if one fails
              continue;
            }
          }
        }
      }

      return products;
    } catch (e) {
      print('[Products] Error loading products: $e');
      handleNetworkError(e);
      rethrow; // Let the UI handle the error
    }
  }

  Future<Report> submitReport(Report report) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Debug logging
      print('REPORT DEBUG: Preparing to submit report:');
      print('REPORT DEBUG: Type: ${report.type.toString().split('.').last}');
      print('REPORT DEBUG: JourneyPlanId: ${report.journeyPlanId}');
      print('REPORT DEBUG: SalesRepId: ${report.salesRepId}');
      print('REPORT DEBUG: ClientId: ${report.clientId}');

      // Prepare request body according to server's expected format
      // The server expects userId instead of salesRepId and a details field
      final Map<String, dynamic> requestBody = {
        'type': report.type.toString().split('.').last,
        'journeyPlanId': report.journeyPlanId,
        'userId': report.salesRepId, // Use salesRepId as userId for server
        'clientId': report.clientId,
      };

      // Add details field based on report type
      switch (report.type) {
        case ReportType.PRODUCT_AVAILABILITY:
          if (report.productReport == null) {
            throw Exception('Product report details are missing');
          }
          requestBody['details'] = {
            'productName': report.productReport!.productName,
            'quantity': report.productReport!.quantity,
            'comment': report.productReport!.comment,
          };
          break;
        case ReportType.VISIBILITY_ACTIVITY:
          if (report.visibilityReport == null) {
            throw Exception('Visibility report details are missing');
          }
          requestBody['details'] = {
            'comment': report.visibilityReport!.comment,
            'imageUrl': report.visibilityReport!.imageUrl,
          };
          break;
        case ReportType.FEEDBACK:
          if (report.feedbackReport == null) {
            throw Exception('Feedback report details are missing');
          }
          requestBody['details'] = {
            'comment': report.feedbackReport!.comment,
          };
          break;
      }

      print('REPORT DEBUG: Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: await _headers(),
        body: jsonEncode(requestBody),
      );

      print('REPORT DEBUG: Response status: ${response.statusCode}');
      print('REPORT DEBUG: Response body: ${response.body}');

      if (response.statusCode == 201) {
        // Parse the server response
        final data = jsonDecode(response.body);

        // The server returns { report: {...}, specificReport: {...} }
        // We need to merge these to create a single Report object
        if (data['report'] != null && data['specificReport'] != null) {
          // Copy the main report data
          final Map<String, dynamic> mergedData = {...data['report']};

          // Add the specific report type from the original request
          // since it's not returned directly in the format we need
          mergedData['type'] = report.type.toString().split('.').last;

          // Add the specific report data
          final String reportType = report.type.toString().split('.').last;
          mergedData['specificReport'] = {
            ...data['specificReport'],
            'type': reportType // Make sure type is included
          };

          print('REPORT DEBUG: Merged data for parsing: $mergedData');
          return Report.fromJson(mergedData);
        } else {
          // Handle unexpected response format
          print('REPORT DEBUG: Unexpected response format: $data');
          throw Exception('Unexpected response format from server');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to submit report: ${response.statusCode} - ${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error submitting report: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  Future<List<Report>> getReports({
    int? journeyPlanId,
    int? clientId,
    int? salesRepId,
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
      if (clientId != null) queryParams['clientId'] = clientId.toString();
      if (salesRepId != null) queryParams['salesRepId'] = salesRepId.toString();

      final uri =
          Uri.parse('$baseUrl/reports').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _headers(),
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
        headers: await _headers(),
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

  static final _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  static Future<void> _initDioHeaders() async {
    _dio.options.headers = await _headers();
  }

  // Create a new order
  static Future<Order> createOrder({
    required int clientId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _initDioHeaders();

      final requestBody = {
        'clientId': clientId,
        'orderItems': items,
      };

      print('Creating order with body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await _headers(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Order.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to create order');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ??
            'Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  // Update an existing order
  static Future<Order> updateOrder({
    required int orderId,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: await _headers(),
        body: jsonEncode({
          'orderItems': orderItems,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Order.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to update order');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ??
            'Failed to update order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating order: $e');
      throw Exception('Failed to update order: $e');
    }
  }

  // Check if the user is authenticated
  static bool isAuthenticated() {
    final token = _getAuthToken();
    return token != null;
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
          headers: await _headers(),
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
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              attachmentFile,
              filename:
                  'web_document_${DateTime.now().millisecondsSinceEpoch}.jpg',
              contentType: MediaType('application', 'octet-stream'),
            ),
          );
        } else {
          print('Mobile file upload: Adding file from path');
          // Mobile/desktop file upload (File object)
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachment',
              attachmentFile.path,
              filename: attachmentFile.path.split('/').last,
            ),
          );
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
        headers: await _headers(),
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
        headers: await _headers(),
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
        headers: await _headers(),
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
        headers: await _headers(),
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

  static Future<bool> deleteOrder(int orderId) async {
    try {
      print('[DELETE] Attempting to delete order: $orderId');

      final response = await http.delete(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: await _headers(),
      );

      print('[DELETE] Response status: ${response.statusCode}');
      print('[DELETE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to delete order');
      }
    } catch (e) {
      print('[ERROR] Deleting order: $e');
      throw Exception('Failed to delete order: $e');
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        final errorMsg = json.decode(response.body)['message'] ??
            'Failed to fetch profile data';
        throw Exception(errorMsg);
      }

      final responseData = json.decode(response.body);
      if (responseData['salesRep'] == null) {
        throw Exception('Invalid response format from server');
      }

      return responseData;
    } catch (e) {
      handleNetworkError(e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/salesRep/profile'),
        headers: await _headers(),
        body: json.encode(data),
      );
      await _handleResponse(response);
      return json.decode(response.body);
    } catch (e) {
      handleNetworkError(e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        print('PASSWORD UPDATE ERROR: No authentication token found');
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.'
        };
      }

      // Debug log
      print('PASSWORD UPDATE: Making request to $baseUrl/profile/password');

      final headers = await _headers();
      // Debug log - sanitized version
      print(
          'PASSWORD UPDATE: Using authorization header: ${headers.containsKey('Authorization') ? 'Yes' : 'No'}');

      final body = {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      };
      // Debug log - don't log the actual password values
      print(
          'PASSWORD UPDATE: Sending request with fields: ${body.keys.toString()}');

      try {
        final response = await http
            .post(
          Uri.parse('$baseUrl/profile/password'),
          headers: headers,
          body: json.encode(body),
        )
            .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('PASSWORD UPDATE ERROR: Request timeout');
            throw Exception("Connection timeout");
          },
        );

        // Debug log
        print('PASSWORD UPDATE: Response status code: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print(
              'PASSWORD UPDATE: Response body length: ${response.body.length}');
          print(
              'PASSWORD UPDATE: Response body sample: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}');
        } else {
          print('PASSWORD UPDATE: Response body is empty');
        }

        // Handle HTTP status codes
        switch (response.statusCode) {
          case 200:
            return {
              'success': true,
              'message': 'Password updated successfully'
            };
          case 400:
            final Map<String, dynamic> errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ??
                  'Invalid request. Please check your inputs.'
            };
          case 401:
            print(
                'PASSWORD UPDATE: Unauthorized - Token may be invalid or expired');
            return {
              'success': false,
              'message': 'Session expired. Please log in again.'
            };
          case 404:
            print(
                'PASSWORD UPDATE: Endpoint not found - Route may be incorrect');
            return {
              'success': false,
              'message':
                  'Password update service not available. Please try again later.'
            };
          default:
            try {
              final Map<String, dynamic> errorData = json.decode(response.body);
              return {
                'success': false,
                'message': errorData['message'] ??
                    'Failed to update password (Status ${response.statusCode})'
              };
            } catch (e) {
              return {
                'success': false,
                'message':
                    'Failed to update password (Status ${response.statusCode})'
              };
            }
        }
      } catch (e) {
        print('PASSWORD UPDATE ERROR: HTTP request error: $e');
        return {
          'success': false,
          'message':
              'Connection error: ${e.toString().replaceAll('Exception:', '')}'
        };
      }
    } catch (e) {
      // Log the specific error
      print('PASSWORD UPDATE ERROR: $e');
      handleNetworkError(e);
      return {
        'success': false,
        'message': 'Network error: Please check your internet connection'
      };
    }
  }

  static Future<String> updateProfilePhoto(XFile photo) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      print(
          'Token for photo upload: ${token.substring(0, 10)}...'); // Debug token

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/profile/photo'),
      );

      // Add authorization header with Bearer token
      request.headers['Authorization'] = 'Bearer $token';

      if (kIsWeb) {
        // For web, XFile provides bytes directly
        final bytes = await photo.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: photo.name,
            contentType: MediaType('image', photo.name.split('.').last),
          ),
        );
      } else {
        // For mobile platforms
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photo.path,
            contentType: MediaType('image', photo.path.split('.').last),
          ),
        );
      }

      print('Sending multipart request for profile photo update');
      final streamedResponse = await request.send();
      print('Response status code: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      print('Response body: ${response.body}'); // Debug response

      if (response.statusCode == 401) {
        print(
            'Token validation failed. Current token: ${token.substring(0, 10)}...');
        throw Exception("Authentication failed. Please log in again.");
      }

      if (response.statusCode != 200) {
        final errorMsg = response.statusCode == 404
            ? 'Profile photo upload endpoint not found. Please check API configuration.'
            : (json.decode(response.body)['message'] ??
                'Failed to update profile photo');
        throw Exception(errorMsg);
      }

      final responseData = json.decode(response.body);
      if (responseData['salesRep'] != null &&
          responseData['salesRep']['photoUrl'] != null) {
        return responseData['salesRep']['photoUrl'];
      }
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('Error updating profile photo: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    try {
      final box = GetStorage();
      await box.remove('token');
      await box.remove('salesRep');
      final authController = Get.find<AuthController>();
      authController.isLoggedIn.value = false;
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Create a new outlet/client
  static Future<Client> createOutlet({
    required String name,
    required String address,
    String? taxPin,
    String? email,
    String? contact,
    double? latitude,
    double? longitude,
    String? location,
    int? clientType,
    int? regionId,
    String? region,
    int? countryId,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/outlets'),
        headers: await _headers(),
        body: jsonEncode({
          'name': name,
          'address': address,
          if (taxPin != null) 'tax_pin': taxPin,
          if (email != null) 'email': email,
          if (contact != null) 'contact': contact,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (location != null) 'location': location,
          if (clientType != null) 'client_type': clientType,
          if (regionId != null) 'region_id': regionId,
          if (region != null) 'region': region,
          if (countryId != null) 'country': countryId,
        }),
      );

      if (response.statusCode == 201) {
        return Client.fromJson(jsonDecode(response.body));
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to create outlet: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error in createOutlet: $e');
      throw Exception('An error occurred while creating the outlet: $e');
    }
  }

  // Get current user's assigned office information
  static Future<Map<String, dynamic>> getCurrentUserOffice() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        // Get all offices from the office endpoint
        final response = await http
            .get(
              Uri.parse('$baseUrl/office'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> offices = jsonDecode(response.body);

          // For now, just return the first office if any exists
          if (offices.isNotEmpty) {
            return offices[0];
          }
        }
      } catch (apiError) {
        // Log the API error, but continue to provide fallback data
        print('API error: $apiError');
      }

      // Return default office data if the endpoint fails or no offices found
      return {
        'id': 1,
        'name': 'Main Office',
        'address': 'Company Headquarters',
        'latitude': 0.0,
        'longitude': 0.0
      };
    } catch (e) {
      print('Error fetching user office: $e');
      handleNetworkError(e);
      throw Exception('Failed to load user office information');
    }
  }
}
