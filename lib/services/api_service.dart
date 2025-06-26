import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart'
    hide FormData, MultipartFile; // Hide conflicting imports
import 'package:http_parser/http_parser.dart';
import 'package:woosh/models/hive/pending_journey_plan_model.dart';
import 'package:woosh/models/hive/route_model.dart';
// Generated files cannot be directly imported
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/noticeboard_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/user_model.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/hive/route_hive_service.dart';
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
import 'package:woosh/models/clientPayment_model.dart';
import 'package:woosh/models/uplift_sale_model.dart';
import 'package:woosh/models/store_model.dart';
// Handle platform-specific imports
import 'image_upload.dart';
import 'package:image/image.dart' as img;
import 'package:woosh/services/offline_toast_service.dart';
import 'package:woosh/services/token_service.dart';

// API Caching System
class ApiCache {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static final Map<String, Duration> _cacheDuration = {};
  static const Duration defaultCacheValidity = Duration(minutes: 5);

  static void set(String key, dynamic data, {Duration? validity}) {
    _cache[key] = data;
    _cacheTimestamp[key] = DateTime.now();
    _cacheDuration[key] = validity ?? defaultCacheValidity;
  }

  static dynamic get(String key) {
    if (!_cache.containsKey(key)) return null;

    final timestamp = _cacheTimestamp[key]!;
    final duration = _cacheDuration[key] ?? defaultCacheValidity;

    if (DateTime.now().difference(timestamp) > duration) {
      _cache.remove(key);
      _cacheTimestamp.remove(key);
      _cacheDuration.remove(key);
      return null;
    }
    return _cache[key];
  }

  static void clear() {
    _cache.clear();
    _cacheTimestamp.clear();
    _cacheDuration.clear();
  }

  static void remove(String key) {
    _cache.remove(key);
    _cacheTimestamp.remove(key);
    _cacheDuration.remove(key);
  }

  static void setCacheDuration(String key, Duration duration) {
    if (_cache.containsKey(key)) {
      _cacheDuration[key] = duration;
    }
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
  static const Duration tokenExpirationDuration = Duration(hours: 9);
  static bool _isRefreshing = false;
  static Future<bool>? _refreshFuture;
  static const String _updatedClientsKey = 'updated_client_locations';

  static String? _getAuthToken() {
    try {
      // Use new TokenService for access token
      return TokenService.getAccessToken();
    } catch (e) {
      print('Error reading token from storage: $e');
      return null;
    }
  }

  // Add refresh token method
  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = TokenService.getRefreshToken();
      if (refreshToken == null) {
        print('No refresh token available');
        return false;
      }

      print('Attempting to refresh access token');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refreshToken': refreshToken,
        }),
      );

      print('Refresh response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store new access token with refresh token
        await TokenService.storeTokens(
          accessToken: data['accessToken'],
          refreshToken: refreshToken, // Keep same refresh token
          expiresIn: data['expiresIn'],
        );

        print('Access token refreshed successfully');
        return true;
      }

      print('Token refresh failed: ${response.body}');
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  static Future<bool> _shouldRefreshToken() async {
    try {
      // Use new TokenService to check if token is expired
      return TokenService.isTokenExpired();
    } catch (e) {
      print('Error checking token expiration: $e');
      return false;
    }
  }

  static Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      print('Token refresh already in progress');
      final result = await _refreshFuture;
      return result ?? false;
    }

    _isRefreshing = true;
    _refreshFuture = Future<bool>(() async {
      try {
        print('Attempting to refresh token');
        final refreshed = await refreshAccessToken();

        if (refreshed) {
          print('Token refreshed successfully');
          return true;
        } else {
          print('Token refresh failed');
          return false;
        }
      } catch (e) {
        print('Error refreshing token: $e');
        return false;
      } finally {
        _isRefreshing = false;
      }
    });

    return await _refreshFuture!;
  }

  static Future<Map<String, String>> _headers(
      [String? additionalContentType]) async {
    try {
      final token = _getAuthToken();
      print(
          '🔑 Current access token: ${token != null ? "Present" : "Missing"}');
      if (token != null) {
        print('🔑 Token preview: ${token.substring(0, 20)}...');
      }

      if (await _shouldRefreshToken()) {
        print('🔄 Token needs refresh, attempting...');
        final refreshed = await _refreshToken();
        if (!refreshed) {
          print('❌ Token refresh failed');
          await logout();
          throw Exception("Session expired. Please log in again.");
        }
        print('✅ Token refreshed successfully');

        // Get the new token after refresh
        final newToken = _getAuthToken();
        print(
            '🔑 New token after refresh: ${newToken != null ? "Present" : "Missing"}');
      }

      final headers = {
        'Content-Type': additionalContentType ?? 'application/json',
        'Authorization': 'Bearer $token',
      };
      print('📤 Request headers prepared: ${headers.keys.join(', ')}');
      print(
          '📤 Authorization header: ${headers['Authorization']?.substring(0, 30)}...');
      return headers;
    } catch (e) {
      print('❌ Error preparing headers: $e');
      rethrow;
    }
  }

  /// Get headers for API requests with optional content type
  static Future<Map<String, String>> headers(
      [String? additionalContentType]) async {
    return _headers(additionalContentType);
  }

  static void handleNetworkError(dynamic error) {
    // Log the error for debugging but don't show raw error to user
    print('Network error occurred: $error');

    String errorMessage = "Unable to connect to the server";

    if (error.toString().contains('SocketException') ||
        error.toString().contains('XMLHttpRequest error') ||
        error.toString().contains('Connection timeout') ||
        error.toString().contains('Failed to fetch') ||
        error.toString().contains('ClientException')) {
      errorMessage = "You're offline. Please check your internet connection.";
    } else if (error.toString().contains('TimeoutException')) {
      errorMessage = "Request timed out. Please try again.";
    } else if (error.toString().contains('500')) {
      errorMessage = "Server error. Please try again later.";
    }

    // Always show the offline toast instead of raw error
    OfflineToastService.showOfflineToast(
      message: errorMessage,
      duration: const Duration(seconds: 4),
      onRetry: () {
        Get.back();
      },
    );
  }

  static Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Try to refresh token first
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        // Refresh failed, clear all tokens and logout
        await TokenService.clearTokens();

        // Clear other stored data
        final box = GetStorage();
        await box.remove('salesRep');

        // Force logout and redirect to login
        final authController = Get.find<AuthController>();
        await authController.logout();
        Get.offAllNamed('/login');

        throw Exception("Session expired. Please log in again.");
      }
      // If refresh succeeded, the original request should be retried
      throw Exception("Token refreshed, retry request");
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

  // Fetch Clients with route filtering and pagination
  static Future<PaginatedResponse<Client>> fetchClients({
    int? routeId,
    int page = 1,
    int limit = 20000,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'fields': 'id,name,longitude,latitude,route_id',
        if (routeId != null) 'route_id': routeId.toString(),
      };

      final uri =
          Uri.parse('$baseUrl/outlets').replace(queryParameters: queryParams);
      final response = await http
          .get(
        uri,
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
        final Map<String, dynamic> responseData =
            json.decode(handledResponse.body);
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> data = responseData['data'];
          return PaginatedResponse<Client>(
            data: data.map((json) {
              return Client(
                  id: json['id'],
                  name: json['name'],
                  address: json['address'] ?? '',
                  latitude: json['latitude'] != null
                      ? (json['latitude'] as num).toDouble()
                      : null,
                  longitude: json['longitude'] != null
                      ? (json['longitude'] as num).toDouble()
                      : null,
                  regionId: json['region_id'] ?? 0,
                  region: json['region'] ?? '',
                  countryId: json['country_id'] ?? 0);
            }).toList(),
            total: responseData['total'] ?? 0,
            page: responseData['page'] ?? 1,
            limit: responseData['limit'] ?? 20000,
            totalPages: responseData['totalPages'] ?? 1,
          );
        } else {
          throw Exception(
              'Invalid response format: missing data field or not a list');
        }
      } else {
        throw Exception(
            'Failed to load clients: ${handledResponse.statusCode}');
      }
    } catch (e) {
      handleNetworkError(e);
      rethrow;
    }
  }

  // Get clients by route with pagination
  static Future<PaginatedResponse<Client>> getClientsByRoute(
    int routeId, {
    int page = 1,
    int limit = 20000,
  }) async {
    return fetchClients(routeId: routeId, page: page, limit: limit);
  }

  // Get current user's route ID
  static int? getCurrentUserRouteId() {
    final box = GetStorage();
    final salesRep = box.read('salesRep');
    if (salesRep != null && salesRep is Map<String, dynamic>) {
      return salesRep['route_id'];
    }
    return null;
  }

  // Get clients for current user's route with pagination
  static Future<PaginatedResponse<Client>> getClientsForCurrentRoute({
    int page = 1,
    int limit = 20000,
  }) async {
    final routeId = getCurrentUserRouteId();
    if (routeId == null) {
      throw Exception('User route not found');
    }
    return getClientsByRoute(routeId, page: page, limit: limit);
  }

  // Clear outlets cache
  static void clearOutletsCache() {
    final box = GetStorage();
    final keys = box.getKeys();
    for (final key in keys) {
      if (key.startsWith('outlets_page_')) {
        ApiCache.remove(key);
      }
    }
  }

  // Keep fetchOutlets for backward compatibility
  @Deprecated('Use fetchClients() instead')
  static Future<List<Outlet>> fetchOutlets({
    int page = 1,
    int limit = 20000,
    int? routeId,
    DateTime? createdAfter,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Generate cache key based on page, limit, route and createdAfter
      final cacheKey =
          'outlets_page_${page}_limit_$limit${routeId != null ? '_route_$routeId' : ''}${createdAfter != null ? '_after_${createdAfter.toIso8601String()}' : ''}';

      // Try to get from cache first
      final cachedData = ApiCache.get(cacheKey);
      if (cachedData != null) {
        return (cachedData as List)
            .map((json) => Outlet.fromJson(json))
            .toList();
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (routeId != null) 'route_id': routeId.toString(),
        if (createdAfter != null)
          'created_after': createdAfter.toIso8601String(),
      };

      final uri =
          Uri.parse('$baseUrl/outlets').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> data = responseData['data'];

          // Cache the response with a shorter duration for paginated data
          ApiCache.set(
            cacheKey,
            data,
            validity: const Duration(minutes: 2),
          );

          return data.map((json) => Outlet.fromJson(json)).toList();
        } else {
          throw Exception(
              'Invalid response format: missing data field or not a list');
        }
      } else {
        throw Exception('Failed to load outlets: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching outlets: $e');
      throw Exception('Failed to load outlets: $e');
    }
  }

  // Create a Journey Plan
  static Future<JourneyPlan> createJourneyPlan(int clientId, DateTime dateTime,
      {String? notes, int? routeId}) async {
    try {
      print(
          'Creating journey plan with clientId: $clientId, date: ${dateTime.toIso8601String()}, notes: $notes, routeId: $routeId');
      // Debug: print the entire request body and user
      print('--- Incoming createJourneyPlan request ---');
      print(
          'req.body: $clientId, date: ${dateTime.toIso8601String()}, notes: $notes, routeId: $routeId');
      print('req.user: $clientId');

      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      // Format time as HH:MM:SS
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

      print(
          'Creating journey plan with clientId: $clientId, date: ${dateTime.toIso8601String()}, time: $time, notes: $notes, routeId: $routeId');

      final Map<String, dynamic> requestBody = {
        'clientId': clientId,
        'date': dateTime.toIso8601String(),
        'time': time,
      };

      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      if (routeId != null) {
        requestBody['routeId'] = routeId;
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

  static Future<void> createJourneyPlanOffline(
    int clientId,
    DateTime date, {
    String? notes,
    int? routeId,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: await _headers(),
        body: jsonEncode({
          'clientId': clientId,
          'date': date.toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (routeId != null) 'routeId': routeId,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Failed to create journey plan: ${response.statusCode}');
      }

      // Clear journey plans cache to force refresh
      ApiCache.remove('journey_plans');
    } catch (e) {
      print('Error creating journey plan: $e');

      // Check if it's a network error
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection') ||
          e.toString().contains('Network')) {
        // Store the journey plan locally for later sync
        try {
          final pendingService = Get.find<PendingJourneyPlanHiveService>();
          final pendingPlan = PendingJourneyPlanModel(
            clientId: clientId,
            date: date,
            notes: notes,
            routeId: routeId,
            createdAt: DateTime.now(),
            status: 'pending',
          );
          await pendingService.savePendingJourneyPlan(pendingPlan);
          return; // Return without throwing exception as we've saved it locally
        } catch (hiveError) {
          print('Error saving pending journey plan: $hiveError');
        }
      }

      throw Exception('Failed to create journey plan: $e');
    }
  }

  // Fetch Journey Plans
  static Future<List<JourneyPlan>> fetchJourneyPlans(
      {int page = 1, int limit = 2000}) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/journey-plans')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _headers());

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
        throw Exception('Failed to load journey plans: ${response.statusCode}');
      }
    } catch (e) {
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

  // Delete Journey Plan
  static Future<void> deleteJourneyPlan(int journeyId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

      print('Deleting journey plan: $journeyId');
      print('URL: $url');

      final response = await http.delete(
        url,
        headers: await _headers(),
      );

      print('Delete journey plan response status: ${response.statusCode}');
      print('Delete journey plan response body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        print('Journey plan deleted successfully: ${decodedJson['message']}');
        return;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to delete journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error in deleteJourneyPlan: $e');
      throw Exception('An error occurred while deleting the journey plan: $e');
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
  static Future<String> uploadImage(
    dynamic imageFile, {
    void Function(double)? onProgress,
    int maxWidth = 1200,
    int quality = 85,
  }) async {
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

      // Handle mobile platform
      if (!kIsWeb) {
        if (imageFile is File) {
          // Optimize image before upload
          final bytes = await _optimizeImage(
            await File(imageFile.path).readAsBytes(),
            maxWidth: maxWidth,
            quality: quality,
          );
          final fileName = imageFile.path.split('/').last;
          final fileExtension = fileName.split('.').last.toLowerCase();

          // Validate file type
          final allowedTypes = ['jpg', 'jpeg', 'png', 'pdf'];
          if (!allowedTypes.contains(fileExtension)) {
            throw Exception(
                'Invalid file type. Only JPG, JPEG, PNG, and PDF files are allowed.');
          }

          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              bytes,
              filename: fileName,
              contentType: MediaType('image', fileExtension),
            ),
          );
        } else {
          throw Exception(
              'Invalid file type for mobile platform. Expected File.');
        }
      } else {
        // Handle web platform
        if (imageFile is XFile) {
          // Optimize image before upload
          final bytes = await _optimizeImage(
            await imageFile.readAsBytes(),
            maxWidth: maxWidth,
            quality: quality,
          );
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              bytes,
              filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        } else {
          throw Exception('Invalid file type for web platform');
        }
      }

      // Track upload progress
      final streamedResponse = await request.send();
      final totalBytes = streamedResponse.contentLength ?? 0;
      var receivedBytes = 0;

      // Create a Completer to handle the response
      final completer = Completer<String>();
      final responseBytes = <int>[];

      streamedResponse.stream.listen(
        (chunk) {
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
          responseBytes.addAll(chunk);
        },
        onDone: () {
          final response = http.Response.bytes(
            responseBytes,
            streamedResponse.statusCode,
            headers: streamedResponse.headers,
          );

          if (response.statusCode == 200) {
            try {
              final decodedJson = jsonDecode(response.body);
              print('Upload response: $decodedJson'); // Debug log

              // Handle the actual response format from your server
              if (decodedJson['attachment'] != null &&
                  decodedJson['attachment']['main'] != null &&
                  decodedJson['attachment']['main']['url'] != null) {
                completer.complete(decodedJson['attachment']['main']['url']);
              } else {
                throw Exception('Invalid response format from server');
              }
            } catch (e) {
              print('Error parsing response: $e');
              completer.completeError(e);
            }
          } else {
            completer.completeError(
              Exception('Failed to upload image: ${response.statusCode}'),
            );
          }
        },
        onError: (error) {
          print('Upload stream error: $error');
          completer.completeError(error);
        },
        cancelOnError: true,
      );

      return completer.future;
    } catch (e) {
      print('Upload error: $e');
      throw Exception('An error occurred while uploading the image: $e');
    }
  }

  // Helper function to optimize images before upload
  static Future<Uint8List> _optimizeImage(
    Uint8List bytes, {
    required int maxWidth,
    required int quality,
  }) async {
    try {
      // Decode the image
      var image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if needed
      if (image.width > maxWidth) {
        final ratio = maxWidth / image.width;
        final newHeight = (image.height * ratio).round();
        image = img.copyResize(
          image,
          width: maxWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Encode with quality
      return Uint8List.fromList(
        img.encodeJpg(image, quality: quality),
      );
    } catch (e) {
      print('Image optimization error: $e');
      // Return original bytes if optimization fails
      return bytes;
    }
  }

  // User Login
  Future<Map<String, dynamic>> login(
      String phoneNumber, String password) async {
    try {
      print('🔐 Attempting login for: $phoneNumber');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      print('🔐 Login response status: ${response.statusCode}');
      print('🔐 Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔐 Parsed response data keys: ${data.keys.join(', ')}');

        // Check if the response has the expected structure
        if (data['accessToken'] == null) {
          print('❌ No accessToken in response');
          return {
            'success': false,
            'message': 'Invalid response format: missing accessToken',
          };
        }

        if (data['refreshToken'] == null) {
          print('❌ No refreshToken in response');
          return {
            'success': false,
            'message': 'Invalid response format: missing refreshToken',
          };
        }

        // Store both access and refresh tokens using TokenService
        await TokenService.storeTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
          expiresIn: data['expiresIn'],
        );

        print('✅ Tokens stored successfully');

        // Store user data in GetStorage (keeping existing structure)
        final box = GetStorage();
        box.write('salesRep', data['salesRep']);

        return {
          'success': true,
          'accessToken': data['accessToken'],
          'refreshToken': data['refreshToken'],
          'salesRep': data['salesRep']
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ Login failed: ${error['error'] ?? 'Unknown error'}');
        return {
          'success': false,
          'message': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
      };
    }
  }

  // Register new user
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(userData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Registration successful',
          'salesRep': responseData['salesRep'],
          'token': responseData['token'],
        };
      } else {
        String errorMessage = 'Registration failed';
        if (responseData is Map) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              'Registration failed';

          // Handle validation errors
          if (responseData['errors'] != null) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            errorMessage = errors.entries
                .map((e) => '${e.key}: ${e.value.join(', ')}')
                .join('\n');
          }
        }

        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on FormatException catch (e) {
      print('JSON Format Error: $e');
      return {
        'success': false,
        'message': 'Invalid server response format',
      };
    } on http.ClientException catch (e) {
      print('Network Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    } catch (e) {
      print('Registration error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  static Future<Map<String, String>> getHeaders() async {
    return await _headers();
  }

  // Get products (independent of outlets)
  static Future<List<Product>> getProducts({
    int page = 1,
    int limit = 200,
    String? search,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri =
          Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'] is List) {
          final List<dynamic> productData = data['data'];
          return productData.map((json) => Product.fromJson(json)).toList();
        }
        return [];
      } else {
        print(
            'Failed to load products: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
      rethrow;
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
      final Map<String, dynamic> requestBody = {
        'type': report.type.toString().split('.').last,
        'journeyPlanId': report.journeyPlanId,
        'userId': report.salesRepId, // Use salesRepId as userId for server
        'clientId': report.clientId,
      };

      // Add details field based on report type
      switch (report.type) {
        case ReportType.PRODUCT_AVAILABILITY:
          if (report.productReports == null || report.productReports!.isEmpty) {
            throw Exception('Product report details are missing');
          }
          requestBody['details'] = report.productReports!
              .map((product) => {
                    'productName': product.productName,
                    'productId': product.productId,
                    'quantity': product.quantity,
                    'comment': product.comment,
                  })
              .toList();
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
        case ReportType.PRODUCT_RETURN:
          if (report.productReturnItems == null ||
              report.productReturnItems!.isEmpty) {
            throw Exception('Product return items are missing');
          }
          requestBody['details'] = {
            'items': report.productReturnItems!
                .map((item) => {
                      'productName': item.productName,
                      'quantity': item.quantity,
                      'reason': item.reason,
                    })
                .toList(),
          };
          break;
        case ReportType.PRODUCT_SAMPLE:
          if (report.productSampleItems == null ||
              report.productSampleItems!.isEmpty) {
            throw Exception('Product sample items are missing');
          }
          requestBody['details'] = {
            'items': report.productSampleItems!
                .map((item) => {
                      'productName': item.productName,
                      'quantity': item.quantity,
                      'reason': item.reason,
                    })
                .toList(),
          };
          break;
        default:
          // Optionally handle unknown types
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

        // For product returns, samples, feedback, visibility, and product availability, the response is an array with a single object
        if ((report.type == ReportType.PRODUCT_RETURN ||
                report.type == ReportType.PRODUCT_SAMPLE ||
                report.type == ReportType.FEEDBACK ||
                report.type == ReportType.VISIBILITY_ACTIVITY ||
                report.type == ReportType.PRODUCT_AVAILABILITY) &&
            data is List) {
          if (data.isNotEmpty) {
            final returnData = data.first;
            return Report.fromJson({
              ...returnData,
              'type': report.type.toString().split('.').last,
            });
          }
        }

        // For other report types, handle the standard response format
        if (data['report'] != null) {
          // Copy the main report data
          final Map<String, dynamic> mergedData = {...data['report']};

          // Add the specific report type from the original request
          mergedData['type'] = report.type.toString().split('.').last;

          // Add the specific report data if it exists
          if (data['specificReport'] != null) {
            if (data['specificReport'] is List) {
              // Handle array of product reports
              mergedData['productReports'] = data['specificReport'];
            } else {
              // Handle single specific report
              mergedData['specificReport'] = data['specificReport'];
            }
          }

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
    String? endDate,
    String? startDate,
    String? type,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (journeyPlanId != null) {
        queryParams['journeyPlanId'] = journeyPlanId.toString();
      }
      if (clientId != null) queryParams['clientId'] = clientId.toString();
      if (salesRepId != null) queryParams['salesRepId'] = salesRepId.toString();
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (type != null) queryParams['type'] = type;

      final uri =
          Uri.parse('$baseUrl/reports').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Process each report and safely handle any parsing errors
        final reports = <Report>[];
        for (final json in data) {
          try {
            final report = Report.fromJson(json);
            reports.add(report);
          } catch (e) {
            print('WARNING: Failed to parse report: $e');
            print('JSON that caused error: $json');
            // Skip this report but continue parsing others
          }
        }

        return reports;
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
    int limit = 100,
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

      print('Orders response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];

          // Log a sample of date fields for debugging
          if (data.isNotEmpty && data[0] != null) {
            print('Sample order dates from API:');
            print('createdAt: ${data[0]['createdAt']}');
            print('updatedAt: ${data[0]['updatedAt']}');
          }

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
  static Future<dynamic> createOrder({
    required int clientId,
    required List<Map<String, dynamic>> items,
    dynamic imageFile,
    String? comment, // Add comment parameter
  }) async {
    try {
      await _initDioHeaders();

      // Get user info from storage to include region and country IDs
      final box = GetStorage();
      final salesRep = box.read('salesRep');

      // Extract region and country IDs from the stored user data
      final int? regionId = salesRep != null && salesRep is Map<String, dynamic>
          ? salesRep['region_id'] ?? salesRep['regionId']
          : null;
      final int? countryId =
          salesRep != null && salesRep is Map<String, dynamic>
              ? salesRep['countryId']
              : null;

      // Upload image if provided
      String? imageUrl;
      if (imageFile != null) {
        try {
          print('Uploading image before creating order...');
          imageUrl = await uploadImage(imageFile);
          print('Image uploaded successfully. URL: $imageUrl');
        } catch (e) {
          print('Error uploading image: $e');
          // Continue with order creation even if image upload fails
        }
      }

      final requestBody = {
        'clientId': clientId,
        'orderItems': items,
        'regionId': regionId,
        'countryId': countryId,
        'storeId': items.isNotEmpty
            ? items[0]['storeId']
            : null, // Add storeId from first item
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (comment != null) 'comment': comment, // Add comment to request body
      };

      print(
          '[Order Debug] Including user region/country: regionId=$regionId, countryId=$countryId');

      print('=== Creating Order ===');
      print('Request URL: $baseUrl/orders');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Order Items Count: ${items.length}');
      print('Order Items Details:');
      for (var item in items) {
        print('- Product ID: ${item['productId']}');
        print('  Quantity: ${item['quantity']}');
        print('  Price Option ID: ${item['priceOptionId']}');
      }

      final headers = await _headers();
      print('Request Headers: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle the response safely
        try {
          final responseData = jsonDecode(response.body);

          // Check if this is a balance warning response
          if (responseData['hasOutstandingBalance'] == true) {
            return {
              'hasOutstandingBalance': true,
              'dialog': {
                'title':
                    responseData['dialog']?['title'] ?? 'Outstanding Balance',
                'message': responseData['dialog']?['message'] ??
                    'This client has an outstanding balance.',
              },
            };
          }

          // Handle successful order creation
          if (responseData['success'] == true) {
            // Validate the data structure before parsing
            if (responseData['data'] == null) {
              _showOrderSuccessDialog();
              return null;
            }

            final orderData = responseData['data'];
            if (orderData is! Map<String, dynamic>) {
              _showOrderSuccessDialog();
              return null;
            }

            // Ensure required fields exist
            if (orderData['id'] == null) {
              _showOrderSuccessDialog();
              return null;
            }

            // Parse order as usual
            return Order.fromJson(orderData);
          } else {
            // Handle actual error response
            final errorMessage =
                responseData['error'] ?? 'Failed to create order';
            print('Error from server: $errorMessage');
            throw Exception(errorMessage);
          }
        } catch (e) {
          print('Error parsing server response: $e');
          _showOrderSuccessDialog();
          return null;
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error'] ??
              'Failed to create order: ${response.statusCode}';
          throw Exception(errorMessage);
        } catch (jsonError) {
          print('Error parsing error response: $jsonError');
          throw Exception('Failed to create order: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error creating order: $e');
      // Wrap the error to provide consistent messaging
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to process order: ${e.toString()}');
      }
    }
  }

  static Future<bool> _showBalanceWarningDialog(
    String title,
    String message,
    String type,
  ) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              type == 'warning' ? Icons.warning_amber : Icons.error,
              color: type == 'warning' ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'warning' ? Colors.orange : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  static Future<Order?> createConfirmedOrder({
    required int clientId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      await _initDioHeaders();

      final requestBody = {
        'orderData': orderData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/orders/confirm'),
        headers: await _headers(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (responseData['data'] == null) {
            _showOrderSuccessDialog();
            return null;
          }

          final orderData = responseData['data'];
          if (orderData is! Map<String, dynamic>) {
            throw Exception('Invalid order data format');
          }

          if (orderData['id'] == null) {
            _showOrderSuccessDialog();
            return null;
          }

          return Order.fromJson(orderData);
        } else {
          throw Exception(
              responseData['error'] ?? 'Failed to create confirmed order');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ??
            'Failed to create confirmed order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating confirmed order: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Failed to process confirmed order: ${e.toString()}');
      }
    }
  }

  static void _showOrderSuccessDialog() {
    // This function should be called from a context where Get.dialog can be used
    Future.delayed(Duration.zero, () {
      Get.dialog(
        AlertDialog(
          title: const Text('Order Placed'),
          content: const Text(
              'Your order was placed successfully!\nYou can view your orders for more details.'),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                Get.offNamed('/orders');
              },
              child: const Text('View Orders'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    });
  }

  // Update an existing order
  static Future<Order> updateOrder({
    required int orderId,
    required List<Map<String, dynamic>> orderItems,
    String? comment, // Add comment parameter
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
          if (comment != null)
            'comment': comment, // Add comment to request body
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
          ..headers.addAll(await _headers());

        request.fields['leaveType'] = leaveType;
        request.fields['startDate'] = startDate;
        request.fields['endDate'] = endDate;
        request.fields['reason'] = reason;

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
        print('Response status code: ${streamedResponse.statusCode}');
        print('Raw response body: ${response.body}'); // Added detailed logging

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
    double latitude,
    double longitude, {
    int? routeId,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        if (routeId != null) 'route_id': routeId.toString(),
      };

      final response = await http.get(
        Uri.parse('$baseUrl/outlets/nearby')
            .replace(queryParameters: queryParams),
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
      final response = await _safeGet(
        '$baseUrl/profile',
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        // Use a generic error message instead of raw error
        throw Exception('Unable to fetch profile data');
      }

      final responseData = json.decode(response.body);
      if (responseData['salesRep'] == null) {
        throw Exception('Unable to fetch profile data');
      }

      return responseData;
    } catch (e) {
      handleNetworkError(e);
      // Return empty data instead of rethrowing
      return {'salesRep': null};
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

      // Debug logging
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
              'PASSWORD UPDATE: Response body sample: ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}');
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
      final headers = await _headers();
      request.headers.addAll(headers);

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
      print('Response status code: ${streamedResponse.statusCode}');
      print('Raw response body: ${response.body}'); // Added detailed logging

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
      print('Profile photo update response: $responseData'); // Debug log

      // Handle different response formats
      if (responseData['salesRep'] != null &&
          responseData['salesRep']['photoUrl'] != null) {
        // Format: { salesRep: { photoUrl: "..." } }
        return responseData['salesRep']['photoUrl'];
      } else if (responseData['photoUrl'] != null) {
        // Format: { photoUrl: "..." }
        return responseData['photoUrl'];
      } else if (responseData['data'] != null &&
          responseData['data']['photoUrl'] != null) {
        // Format: { data: { photoUrl: "..." } }
        return responseData['data']['photoUrl'];
      } else if (responseData['user'] != null &&
          responseData['user']['photoUrl'] != null) {
        // Format: { user: { photoUrl: "..." } }
        return responseData['user']['photoUrl'];
      } else {
        print('Unexpected response format: $responseData');
        throw Exception(
            'Invalid response format from server. Please try again.');
      }
    } catch (e) {
      print('Error updating profile photo: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    try {
      // Call logout API endpoint if we have a token
      final accessToken = TokenService.getAccessToken();
      if (accessToken != null) {
        try {
          await http.post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          );
        } catch (e) {
          print('Logout API call failed: $e');
          // Continue with local logout even if API call fails
        }
      }

      // Clear all tokens using TokenService
      await TokenService.clearTokens();

      // Clear other stored data
      final box = GetStorage();
      await box.remove('salesRep');

      // Call auth controller logout
      final authController = Get.find<AuthController>();
      await authController.logout();
    } catch (e) {
      print('Error during logout: $e');
      // Ensure tokens are cleared even if there's an error
      await TokenService.clearTokens();
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
    int? routeId,
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
          if (routeId != null) 'route_id': routeId,
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

  static Future<List<ClientPayment>> getClientPayments(int clientId) async {
    final token = _getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/outlets/$clientId/payments'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => ClientPayment.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch client payments');
    }
  }

  static Future<void> uploadClientPayment({
    required int clientId,
    required double amount,
    required File imageFile,
    Uint8List? imageBytes,
    String? method,
  }) async {
    final token = _getAuthToken();
    final box = GetStorage();
    final salesRep = box.read('salesRep');
    final userId = salesRep != null && salesRep is Map<String, dynamic>
        ? salesRep['id']
        : null;

    if (userId == null) {
      throw Exception("User ID not found. Please login again.");
    }

    print('\n=== DEBUG: Payment Upload Request ===');
    print('Token exists: ${token?.isNotEmpty ?? false}');
    print('Token length: ${token?.length ?? 0}');
    print('Token sample: ${token?.substring(0, 10) ?? ''}...');

    final uri = Uri.parse('$baseUrl/outlets/$clientId/payments');
    print('URL: $uri');
    print('ClientId: $clientId');
    print('Amount: $amount');
    print('Method: $method');
    print('UserId: $userId');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers());

    print('\nDEBUG: Request Headers');
    print('Headers: ${request.headers}');

    request.fields['amount'] = amount.toString();
    request.fields['userId'] = userId.toString(); // Add userId to request
    if (method != null) {
      request.fields['method'] = method;
    }
    print('\nDEBUG: Request Fields');
    print('Fields: ${request.fields}');

    if (kIsWeb && imageBytes != null) {
      print('\nDEBUG: Web Platform File Upload');
      print('Image bytes length: ${imageBytes.length}');
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'payment_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    } else {
      print('\nDEBUG: Mobile Platform File Upload');
      print('Image exists: ${await imageFile.exists()}');
      print('Image path: ${imageFile.path}');
      print('Image size: ${await imageFile.length()} bytes');
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', imageFile.path.split('.').last),
        ),
      );
    }

    print('\nDEBUG: Request Files');
    print('Files count: ${request.files.length}');
    for (var file in request.files) {
      print('File field: ${file.field}');
      print('File filename: ${file.filename}');
      print('File length: ${file.length}');
      print('File contentType: ${file.contentType}');
    }

    print('\nDEBUG: Sending Request');
    final streamedResponse = await request.send();
    print('Response status code: ${streamedResponse.statusCode}');

    final response = await http.Response.fromStream(streamedResponse);
    print('\nDEBUG: Response Body');
    print('Response body: ${response.body}');

    if (response.statusCode != 201) {
      final errorBody = json.decode(response.body);
      print('\nDEBUG: Error Details');
      print('Error: ${errorBody['error']}');
      print('Status code: ${response.statusCode}');
      throw Exception(
          errorBody['error'] ?? 'Failed to upload payment: ${response.body}');
    }

    print('\nDEBUG: Upload Successful');
    print('Status code: ${response.statusCode}');
    print('Response: ${response.body}');
  }

  static T? getCachedData<T>(String key) {
    return ApiCache.get(key) as T?;
  }

  static void cacheData<T>(String key, T data, {Duration? validity}) {
    ApiCache.set(key, data, validity: validity);
  }

  static void clearCache() {
    ApiCache.clear();
  }

  static void removeFromCache(String key) {
    ApiCache.remove(key);
  }

  static Future<JourneyPlan?> getActiveVisit() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/journey-plans?status=in_progress'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['data'] != null && data['data'].isNotEmpty) {
          // Return the first in-progress visit
          return JourneyPlan.fromJson(data['data'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error getting active visit: $e');
      return null;
    }
  }

  static Future<List<Client>> getClients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
        throw Exception('Failed to load clients: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching clients: $e');
      throw Exception('Failed to load clients: $e');
    }
  }

  static Future<Map<String, dynamic>?> createUpliftSale({
    required int clientId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final authHeaders = await headers();
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      final userId = salesRep != null && salesRep is Map<String, dynamic>
          ? salesRep['id']
          : null;

      if (userId == null) {
        throw Exception('User ID not found. Please login again.');
      }

      print('[UpliftSale] Creating sale with data:');
      print('clientId: $clientId');
      print('userId: $userId');
      print('items: $items');

      final response = await http.post(
        Uri.parse('$baseUrl/uplift-sales'),
        headers: authHeaders,
        body: jsonEncode({
          'clientId': clientId,
          'userId': userId,
          'items': items,
        }),
      );

      print('[UpliftSale] Response status: ${response.statusCode}');
      print('[UpliftSale] Response data: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating uplift sale: $e');
      rethrow;
    }
  }

  static Future<List<UpliftSale>?> getUpliftSales({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? clientId,
    int? userId,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (clientId != null) 'clientId': clientId.toString(),
        if (userId != null) 'userId': userId.toString(),
      };

      final uri = Uri.parse('$baseUrl/uplift-sales')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> upliftData = data['data'] ?? [];
        return upliftData.map((json) => UpliftSale.fromJson(json)).toList();
      }
      return null;
    } catch (e) {
      print('Error getting uplift sales: $e');
      rethrow;
    }
  }

  static Future<UpliftSale?> getUpliftSaleById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/uplift-sales/$id'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpliftSale.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('Error getting uplift sale: $e');
      rethrow;
    }
  }

  static Future<bool> updateUpliftSaleStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/uplift-sales/$id/status'),
        headers: await _headers(),
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating uplift sale status: $e');
      rethrow;
    }
  }

  static Future<bool> deleteUpliftSale(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/uplift-sales/$id'),
        headers: await _headers(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting uplift sale: $e');
      rethrow;
    }
  }

  static bool hasClientLocationBeenUpdated(int clientId) {
    final box = GetStorage();
    final List<dynamic>? updatedClients = box.read(_updatedClientsKey);
    return updatedClients?.contains(clientId) ?? false;
  }

  static void markClientLocationAsUpdated(int clientId) {
    final box = GetStorage();
    final List<dynamic> updatedClients = box.read(_updatedClientsKey) ?? [];
    if (!updatedClients.contains(clientId)) {
      updatedClients.add(clientId);
      box.write(_updatedClientsKey, updatedClients);
    }
  }

  // Update client location coordinates
  static Future<Client> updateClientLocation({
    required int clientId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      // Only send latitude and longitude for the update
      final requestBody = {
        'latitude': latitude,
        'longitude': longitude,
      };

      print('Updating client location with data:');
      print('Client ID: $clientId');
      print('Request body: ${jsonEncode(requestBody)}');

      // Use PATCH instead of PUT for partial updates
      final response = await http.patch(
        Uri.parse('$baseUrl/outlets/$clientId/location'),
        headers: await _headers(),
        body: jsonEncode(requestBody),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (response.statusCode == 200) {
        // Mark this client's location as updated
        markClientLocationAsUpdated(clientId);

        final responseData = jsonDecode(response.body);
        return Client.fromJson(responseData);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to update client location: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error updating client location: $e');
      if (e is SocketException) {
        throw Exception('Network error: Please check your connection.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format.');
      } else {
        throw Exception('Unexpected error: $e');
      }
    }
  }

  // Get a single client by ID
  static Future<Client> getClient(int clientId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/outlets/$clientId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Add null checks and default values
        return Client(
          id: responseData['id'] ?? 0,
          name: responseData['name'] ?? '',
          address: responseData['address'] ?? '',
          balance: responseData['balance']?.toString() ?? '0',
          latitude: responseData['latitude'] != null
              ? (responseData['latitude'] as num).toDouble()
              : null,
          longitude: responseData['longitude'] != null
              ? (responseData['longitude'] as num).toDouble()
              : null,
          email: responseData['email'] ?? '',
          contact: responseData['contact'] ?? '',
          taxPin: responseData['tax_pin'] ?? '',
          location: responseData['location'] ?? '',
          clientType: responseData['client_type'] ?? 1,
          regionId: responseData['region_id'] ?? 0,
          region: responseData['region'] ?? '',
          countryId: responseData['countryId'] ?? 0,
        );
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to get client: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error getting client: $e');
      throw Exception('An error occurred while getting client: $e');
    }
  }

  static Future<List<Store>> getStores() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stores'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Store.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load stores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stores: $e');
      rethrow;
    }
  }

  // Get sales reps by route ID
  static Future<List<SalesRep>> getSalesReps({int? routeId}) async {
    try {
      // Build the URI with route_id if provided
      final uri = Uri.parse('$baseUrl/profile/users').replace(
          queryParameters:
              routeId != null ? {'route_id': routeId.toString()} : null);

      print('Fetching sales reps from: $uri'); // Debug log

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      print('Sales reps response status: ${response.statusCode}'); // Debug log
      print('Sales reps response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SalesRep.fromJson(json)).toList();
      }

      throw Exception('Failed to load sales reps: ${response.statusCode}');
    } catch (e) {
      print('Error fetching sales reps: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to load sales reps: $e');
    }
  }

  // Get available routes
  static Future<List<Map<String, dynamic>>> getRoutes() async {
    // Check cache first
    final cachedRoutes = ApiCache.get('routes');
    if (cachedRoutes != null) {
      print('Returning cached routes');
      return List<Map<String, dynamic>>.from(cachedRoutes);
    }

    try {
      // We won't try to register the adapter here as it should be done in HiveInitializer

      // Try to find RouteHiveService or initialize it if not found
      RouteHiveService routeHiveService;
      try {
        routeHiveService = Get.find<RouteHiveService>();
      } catch (e) {
        // If not found, initialize it
        routeHiveService = RouteHiveService();
        await routeHiveService.init();
        Get.put(routeHiveService);
      }

      // Check if we have routes in Hive
      final hiveRoutes = routeHiveService.getAllRoutes();
      if (hiveRoutes.isNotEmpty) {
        final routesList = hiveRoutes
            .map((route) => {
                  'id': route.id,
                  'name': route.name,
                })
            .toList();

        // Cache the routes
        ApiCache.set('routes', routesList, validity: const Duration(hours: 24));
        return routesList;
      }

      // If not in Hive, fetch from API
      final token = _getAuthToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/routes'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final routesList = data
            .map((route) => {
                  'id': route['id'],
                  'name': route['name'],
                })
            .toList();

        // Save to Hive with error handling
        try {
          final routeModels = data
              .map((route) => RouteModel(
                    id: route['id'],
                    name: route['name'],
                  ))
              .toList();
          await routeHiveService.saveRoutes(routeModels);
          print('Successfully saved ${routeModels.length} routes to Hive');
        } catch (hiveError) {
          print('Error saving routes to Hive: $hiveError');
          // Continue execution even if saving to Hive fails
        }

        // Cache the routes
        ApiCache.set('routes', routesList, validity: const Duration(hours: 24));
        return routesList;
      } else {
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching routes: $e');
      // If offline, try to get from Hive
      try {
        // Try to find RouteHiveService or initialize it if not found
        try {
          RouteHiveService routeHiveService;
          try {
            routeHiveService = Get.find<RouteHiveService>();
          } catch (e) {
            // If not found, initialize it
            routeHiveService = RouteHiveService();
            await routeHiveService.init();
            Get.put(routeHiveService);
          }

          // Safely get routes from Hive
          try {
            final hiveRoutes = routeHiveService.getAllRoutes();
            if (hiveRoutes.isNotEmpty) {
              final routesList = hiveRoutes
                  .map((route) => {
                        'id': route.id,
                        'name': route.name,
                      })
                  .toList();
              print(
                  'Successfully retrieved ${routesList.length} routes from Hive');
              return routesList;
            }
          } catch (routeError) {
            print('Error retrieving routes from Hive: $routeError');
          }
        } catch (serviceError) {
          print('Error with RouteHiveService: $serviceError');
        }
      } catch (hiveError) {
        print('Error fetching routes from Hive: $hiveError');
      }
      throw Exception('Failed to load routes: $e');
    }
  }

  static Future<http.Response> _safeHttpCall(
      Future<http.Response> Function() httpCall) async {
    try {
      final response = await httpCall();
      return response;
    } catch (e) {
      // Handle all network errors with OfflineToast
      handleNetworkError(e);
      // Return a custom error response instead of rethrowing
      return http.Response('{"error": "Network error occurred"}', 503);
    }
  }

  static Future<http.Response> _safeGet(String url,
      {Map<String, String>? headers}) async {
    return _safeHttpCall(() => http.get(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> _safePost(String url,
      {Map<String, String>? headers, Object? body}) async {
    return _safeHttpCall(
        () => http.post(Uri.parse(url), headers: headers, body: body));
  }

  static Future<http.Response> _safePut(String url,
      {Map<String, String>? headers, Object? body}) async {
    return _safeHttpCall(
        () => http.put(Uri.parse(url), headers: headers, body: body));
  }

  static Future<http.Response> _safeDelete(String url,
      {Map<String, String>? headers}) async {
    return _safeHttpCall(() => http.delete(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> _safePatch(String url,
      {Map<String, String>? headers, Object? body}) async {
    return _safeHttpCall(
        () => http.patch(Uri.parse(url), headers: headers, body: body));
  }
}
