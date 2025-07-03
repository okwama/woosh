import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/hive/pending_journey_plan_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';

enum JourneyPlanStatus {
  pending,
  checked_in,
  in_progress,
  completed,
  cancelled
}

class PaginatedJourneyPlanResponse {
  final List<JourneyPlan> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final String? timing; // Changed from int? to String? based on documentation

  PaginatedJourneyPlanResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    this.timing,
  });

  factory PaginatedJourneyPlanResponse.fromJson(Map<String, dynamic> json) {
    // Safe parsing helper function for integers
    int parseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        try {
          // Handle decimal strings by converting to double first, then to int
          if (value.contains('.')) {
            final doubleValue = double.tryParse(value);
            return doubleValue?.toInt() ?? defaultValue;
          }
          return int.parse(value);
        } catch (e) {
          print('PaginatedResponse.parseInt error for value "$value": $e');
          return defaultValue;
        }
      }
      return defaultValue;
    }

    // Debug logging for pagination fields
    print('PaginatedResponse parsing - total: ${json['pagination']?['total']}');
    print('PaginatedResponse parsing - page: ${json['pagination']?['page']}');
    print('PaginatedResponse parsing - limit: ${json['pagination']?['limit']}');
    print(
        'PaginatedResponse parsing - totalPages: ${json['pagination']?['totalPages']}');
    print('PaginatedResponse parsing - timing: ${json['timing']?['total']}');

    return PaginatedJourneyPlanResponse(
      data: (json['data'] as List)
          .map((item) => JourneyPlan.fromJson(item))
          .toList(),
      total: parseInt(json['pagination']?['total'], 0),
      page: parseInt(json['pagination']?['page'], 1),
      limit: parseInt(json['pagination']?['limit'], 20),
      totalPages: parseInt(json['pagination']?['totalPages'], 1),
      timing: json['timing']?['total'],
    );
  }
}

class JourneyPlanService {
  static const String baseUrl = '${Config.baseUrl}/api';
  static const String defaultTimezone = 'Africa/Nairobi';

  /// Get default timezone for date calculations
  static String getDefaultTimezone() {
    return defaultTimezone;
  }

  /// Fetch journey plans with proper server alignment
  static Future<PaginatedJourneyPlanResponse> fetchJourneyPlans({
    int page = 1,
    int limit = 20, // Match server default
    JourneyPlanStatus? status,
    String timezone = defaultTimezone,
    int retryCount = 0,
  }) async {
    const maxRetries = 3;

    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'timezone': timezone,
        if (status != null) 'status': status.name,
      };

      final uri = Uri.parse('$baseUrl/journey-plans')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await ApiService.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        // Debug logging for the full response
        print('Journey Plans API Response: $responseBody');

        // Check success flag
        if (responseBody['success'] != true) {
          throw Exception('Server indicated failure');
        }

        return PaginatedJourneyPlanResponse.fromJson(responseBody);
      } else if (response.statusCode >= 500 && response.statusCode <= 503) {
        throw Exception('Server error ${response.statusCode} - retry');
      } else {
        throw Exception('Failed to load journey plans: ${response.statusCode}');
      }
    } catch (e) {
      // Check if it's a server error and we haven't exceeded max retries
      if ((e.toString().contains('500') ||
              e.toString().contains('501') ||
              e.toString().contains('502') ||
              e.toString().contains('503') ||
              e.toString().contains('Server error')) &&
          retryCount < maxRetries) {
        print(
            'Server error in fetchJourneyPlans, retrying... (${retryCount + 1}/$maxRetries)');
        await Future.delayed(
            Duration(seconds: (retryCount + 1) * 2)); // Exponential backoff
        return fetchJourneyPlans(
          page: page,
          limit: limit,
          status: status,
          timezone: timezone,
          retryCount: retryCount + 1,
        );
      }

      print('Error in fetchJourneyPlans: $e');
      throw Exception('An error occurred while fetching journey plans: $e');
    }
  }

  /// Get a single journey plan by ID
  static Future<JourneyPlan?> getJourneyPlanById(int journeyId) async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

      final response = await http.get(
        url,
        headers: await ApiService.headers(),
      );

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);

        // Handle response format (data field or direct object)
        final journeyPlanData = decodedJson['data'] ?? decodedJson;

        return JourneyPlan.fromJson(journeyPlanData);
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

  /// Get currently active visit
  static Future<JourneyPlan?> getActiveVisit() async {
    try {
      final response = await fetchJourneyPlans(
        status: JourneyPlanStatus.in_progress,
        limit: 1,
      );

      if (response.data.isNotEmpty) {
        return response.data.first;
      }
      return null;
    } catch (e) {
      print('Error getting active visit: $e');
      return null;
    }
  }

  /// Create a new journey plan
  static Future<JourneyPlan> createJourneyPlan(
    int clientId,
    DateTime dateTime, {
    String? notes,
    int? routeId,
    int retryCount = 0,
  }) async {
    const maxRetries = 3;

    try {
      print(
          'Creating journey plan with clientId: $clientId, date: ${dateTime.toIso8601String()}, notes: $notes, routeId: $routeId');

      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      // Format time as HH:MM:SS
      final time =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

      final Map<String, dynamic> requestBody = {
        'clientId': clientId,
        'date': dateTime.toIso8601String(),
        'time': time,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (routeId != null) 'routeId': routeId,
      };

      print('Journey plan request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: await ApiService.headers(),
        body: jsonEncode(requestBody),
      );

      print('Create journey plan response status: ${response.statusCode}');
      print('Create journey plan response body: ${response.body}');

      if (response.statusCode == 201) {
        final decodedJson = jsonDecode(response.body);

        // Handle response format (data field or direct object)
        final journeyPlanData = decodedJson['data'] ?? decodedJson;

        return JourneyPlan.fromJson(journeyPlanData);
      } else if (response.statusCode >= 500 && response.statusCode <= 503) {
        throw Exception('Server error ${response.statusCode} - retry');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to create journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Check if it's a server error and we haven't exceeded max retries
      if ((e.toString().contains('500') ||
              e.toString().contains('501') ||
              e.toString().contains('502') ||
              e.toString().contains('503') ||
              e.toString().contains('Server error')) &&
          retryCount < maxRetries) {
        print(
            'Server error in createJourneyPlan, retrying... (${retryCount + 1}/$maxRetries)');
        await Future.delayed(
            Duration(seconds: (retryCount + 1) * 2)); // Exponential backoff
        return createJourneyPlan(
          clientId,
          dateTime,
          notes: notes,
          routeId: routeId,
          retryCount: retryCount + 1,
        );
      }

      print('Error in createJourneyPlan: $e');
      throw Exception('An error occurred while creating the journey plan: $e');
    }
  }

  /// Minimal checkout - uses server defaults (current time and 0,0 coordinates)
  static Future<JourneyPlan> minimalCheckout(int journeyId) async {
    return fastCheckout(journeyId: journeyId);
  }

  /// Checkout with current location and time
  static Future<JourneyPlan> checkoutWithLocation({
    required int journeyId,
    required double latitude,
    required double longitude,
    DateTime? checkoutTime,
  }) async {
    return fastCheckout(
      journeyId: journeyId,
      checkoutTime: checkoutTime ?? DateTime.now(),
      checkoutLatitude: latitude,
      checkoutLongitude: longitude,
    );
  }

  /// Fast checkout - dedicated endpoint for quick checkout operations
  static Future<JourneyPlan> fastCheckout({
    required int journeyId,
    DateTime? checkoutTime,
    double? checkoutLatitude,
    double? checkoutLongitude,
  }) async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId/checkout');

      final body = <String, dynamic>{
        if (checkoutTime != null)
          'checkoutTime': checkoutTime.toIso8601String(),
        if (checkoutLatitude != null) 'checkoutLatitude': checkoutLatitude,
        if (checkoutLongitude != null) 'checkoutLongitude': checkoutLongitude,
      };

      print('FAST CHECKOUT API REQUEST:');
      print('URL: $url');
      print('Journey ID: $journeyId');
      print('Request Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: await ApiService.headers(),
        body: jsonEncode(body),
      );

      print('FAST CHECKOUT API RESPONSE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);

        // Handle response format (data field or direct object)
        final journeyPlanData = decodedJson['data'] ?? decodedJson;

        print('FAST CHECKOUT SUCCESSFUL:');
        print('Journey ID: ${journeyPlanData['id']}');
        print('Status: ${journeyPlanData['status']}');
        print('Checkout Time: ${journeyPlanData['checkoutTime']}');
        print('Checkout Latitude: ${journeyPlanData['checkoutLatitude']}');
        print('Checkout Longitude: ${journeyPlanData['checkoutLongitude']}');

        return JourneyPlan.fromJson(journeyPlanData);
      } else {
        final errorBody = jsonDecode(response.body);
        print('FAST CHECKOUT ERROR:');
        print('Status Code: ${response.statusCode}');
        print('Error Message: ${errorBody['error'] ?? 'Unknown error'}');

        throw Exception(
            'Failed to checkout journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('FAST CHECKOUT EXCEPTION: $e');
      throw Exception('An error occurred during fast checkout: $e');
    }
  }

  /// Update journey plan (full update with all fields)
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
    int retryCount = 0,
  }) async {
    const maxRetries = 3;

    try {
      final token = TokenService.getAccessToken();
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

      print('API REQUEST - JOURNEY PLAN UPDATE:');
      print('URL: $url');
      print('Journey ID: $journeyId');
      print('Client ID: $clientId');
      print('Status: $statusString');
      print('Request Body: ${jsonEncode(body)}');

      final response = await http.put(
        url,
        headers: await ApiService.headers(),
        body: jsonEncode(body),
      );

      print('API RESPONSE - JOURNEY PLAN UPDATE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);

        // Handle response format (data field or direct object)
        final journeyPlanData = decodedJson['data'] ?? decodedJson;

        if (checkoutTime != null) {
          print('CHECKOUT API - RESPONSE SUCCESSFUL:');
          print('Journey ID: ${journeyPlanData['id']}');
          print('Status: ${journeyPlanData['status']}');
          print('Checkout Time: ${journeyPlanData['checkoutTime']}');
          print('Checkout Latitude: ${journeyPlanData['checkoutLatitude']}');
          print('Checkout Longitude: ${journeyPlanData['checkoutLongitude']}');
        }

        return JourneyPlan.fromJson(journeyPlanData);
      } else if (response.statusCode >= 500 && response.statusCode <= 503) {
        throw Exception('Server error ${response.statusCode} - retry');
      } else {
        final errorBody = jsonDecode(response.body);

        if (checkoutTime != null) {
          print('CHECKOUT API - RESPONSE ERROR:');
          print('Status Code: ${response.statusCode}');
          print('Error Message: ${errorBody['error'] ?? 'Unknown error'}');
        }

        throw Exception(
            'Failed to update journey plan: ${response.statusCode}\n${errorBody['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Check if it's a server error and we haven't exceeded max retries
      if ((e.toString().contains('500') ||
              e.toString().contains('501') ||
              e.toString().contains('502') ||
              e.toString().contains('503') ||
              e.toString().contains('Server error')) &&
          retryCount < maxRetries) {
        print(
            'Server error in updateJourneyPlan, retrying... (${retryCount + 1}/$maxRetries)');
        await Future.delayed(
            Duration(seconds: (retryCount + 1) * 2)); // Exponential backoff
        return updateJourneyPlan(
          journeyId: journeyId,
          clientId: clientId,
          status: status,
          checkInTime: checkInTime,
          latitude: latitude,
          longitude: longitude,
          imageUrl: imageUrl,
          notes: notes,
          checkoutTime: checkoutTime,
          checkoutLatitude: checkoutLatitude,
          checkoutLongitude: checkoutLongitude,
          retryCount: retryCount + 1,
        );
      }

      if (checkoutTime != null) {
        print('CHECKOUT API - EXCEPTION:');
        print('Error: $e');
      }

      throw Exception('An error occurred while updating the journey plan: $e');
    }
  }

  /// Delete journey plan
  static Future<void> deleteJourneyPlan(int journeyId) async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final url = Uri.parse('$baseUrl/journey-plans/$journeyId');

      print('Deleting journey plan: $journeyId');
      print('URL: $url');

      final response = await http.delete(
        url,
        headers: await ApiService.headers(),
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

  /// Create journey plan offline (with local storage fallback)
  static Future<void> createJourneyPlanOffline(
    int clientId,
    DateTime date, {
    String? notes,
    int? routeId,
  }) async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/journey-plans'),
        headers: await ApiService.headers(),
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
      ApiService.removeFromCache('journey_plans');
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

  /// Get journey plans by status
  static Future<PaginatedJourneyPlanResponse> getJourneyPlansByStatus(
    JourneyPlanStatus status, {
    int page = 1,
    int limit = 20,
    String timezone = defaultTimezone,
  }) async {
    return fetchJourneyPlans(
      page: page,
      limit: limit,
      status: status,
      timezone: timezone,
    );
  }

  /// Get pending journey plans
  static Future<PaginatedJourneyPlanResponse> getPendingJourneyPlans({
    int page = 1,
    int limit = 20,
    String timezone = defaultTimezone,
  }) async {
    return getJourneyPlansByStatus(
      JourneyPlanStatus.pending,
      page: page,
      limit: limit,
      timezone: timezone,
    );
  }

  /// Get completed journey plans
  static Future<PaginatedJourneyPlanResponse> getCompletedJourneyPlans({
    int page = 1,
    int limit = 20,
    String timezone = defaultTimezone,
  }) async {
    return getJourneyPlansByStatus(
      JourneyPlanStatus.completed,
      page: page,
      limit: limit,
      timezone: timezone,
    );
  }

  /// Get journey plans for today
  static Future<PaginatedJourneyPlanResponse> getTodayJourneyPlans({
    int page = 1,
    int limit = 20,
    String timezone = defaultTimezone,
  }) async {
    try {
      final token = TokenService.getAccessToken();
      if (token == null) {
        throw Exception("Authentication token is missing");
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'timezone': timezone,
        'date': DateTime.now().toIso8601String().split('T')[0], // Today's date
      };

      final uri = Uri.parse('$baseUrl/journey-plans')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await ApiService.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (responseBody['success'] != true) {
          throw Exception('Server indicated failure');
        }

        return PaginatedJourneyPlanResponse.fromJson(responseBody);
      } else {
        throw Exception(
            'Failed to load today\'s journey plans: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getTodayJourneyPlans: $e');
      throw Exception(
          'An error occurred while fetching today\'s journey plans: $e');
    }
  }
}
