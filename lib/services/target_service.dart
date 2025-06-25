import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:glamour_queen/models/target_model.dart';
import 'package:glamour_queen/models/order_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/utils/config.dart';
import 'package:glamour_queen/services/token_service.dart';

class TargetService {
  static const String baseUrl = '${Config.baseUrl}/api';
  static const Duration _cacheDuration = Duration(minutes: 5);
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Get auth token for API requests
  static String? _getAuthToken() {
    return TokenService.getAccessToken();
  }

  // Get headers for API requests
  static Future<Map<String, String>> _headers() async {
    final token = _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Check if cached data is still valid
  static bool _isCacheValid(String key) {
    if (!_cacheTimestamps.containsKey(key)) return false;
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  // Get cached data
  static dynamic _getCachedData(String key) {
    if (_isCacheValid(key)) {
      return _cache[key];
    }
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    return null;
  }

  // Cache data
  static void _cacheData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  // Get daily visit targets for a user
  static Future<Map<String, dynamic>> getDailyVisitTargets({
    required String userId,
    String? date,
  }) async {
    final cacheKey = 'daily_visits_${userId}_$date';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      print('Debug - Using cached data for key: $cacheKey');
      return cachedData;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Debug - No auth token found');
        return {
          'error': 'No authentication token found',
          'visitTarget': 0,
          'completedVisits': 0,
          'remainingVisits': 0,
          'progress': 0,
          'status': 'Error'
        };
      }

      final queryParams = date != null ? '?date=$date' : '';
      final url = '$baseUrl/targets/daily-visits/$userId$queryParams';
      print('Debug - Making API call to: $url');
      print('Debug - Headers: ${await _headers()}');

      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 5));

      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cacheData(cacheKey, data);
        return data;
      } else if (response.statusCode == 404) {
        return {
          'error': 'Sales rep not found',
          'visitTarget': 0,
          'completedVisits': 0,
          'remainingVisits': 0,
          'progress': 0,
          'status': 'Error'
        };
      } else {
        return {
          'error': 'Failed to fetch daily visit targets',
          'details': response.body,
          'visitTarget': 0,
          'completedVisits': 0,
          'remainingVisits': 0,
          'progress': 0,
          'status': 'Error'
        };
      }
    } catch (e) {
      print('Debug - Error in getDailyVisitTargets: $e');
      return {
        'error': 'Failed to fetch daily visit targets',
        'details': e.toString(),
        'visitTarget': 0,
        'completedVisits': 0,
        'remainingVisits': 0,
        'progress': 0,
        'status': 'Error'
      };
    }
  }

  // Get all targets for the current user
  static Future<List<Target>> getTargets({
    int page = 1,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey =
        'targets_page_${page}_${startDate?.toIso8601String()}_${endDate?.toIso8601String()}';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return [];
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri =
          Uri.parse('$baseUrl/targets').replace(queryParameters: queryParams);
      final response = await http
          .get(
            uri,
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final targets =
            (data as List).map((item) => Target.fromJson(item)).toList();
        _cacheData(cacheKey, targets);
        return targets;
      }
      return [];
    } catch (e) {
      print('Error fetching targets: $e');
      return [];
    }
  }

  // Create a new target
  static Future<Target?> createTarget(Target target) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return null;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/targets'),
            headers: await _headers(),
            body: jsonEncode(target.toJson()),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Target.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error creating target: $e');
      return null;
    }
  }

  // Update an existing target
  static Future<Target?> updateTarget(Target target) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return null;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/targets/${target.id}'),
            headers: await _headers(),
            body: jsonEncode(target.toJson()),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Target.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error updating target: $e');
      return null;
    }
  }

  // Delete a target
  static Future<bool> deleteTarget(int targetId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return false;
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/targets/$targetId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting target: $e');
      return false;
    }
  }

  // Update target progress
  static Future<Target?> updateTargetProgress(
      int targetId, int newValue) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return null;
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/targets/$targetId/progress'),
            headers: await _headers(),
            body: jsonEncode({'currentValue': newValue}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Target.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error updating target progress: $e');
      return null;
    }
  }

  // Get user's sales data from the last two weeks
  static Future<Map<String, dynamic>> getSalesData({
    int page = 1,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey =
        'sales_data_page_${page}_${startDate?.toIso8601String()}_${endDate?.toIso8601String()}';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        print('Error: No authentication token found');
        return {
          'totalItemsSold': 0,
          'orderCount': 0,
          'recentOrders': <dynamic>[],
          'hasMore': false,
        };
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$baseUrl/orders/sales-summary')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final result = {
            'totalItemsSold': data['totalItemsSold'] ?? 0,
            'orderCount': data['orderCount'] ?? 0,
            'recentOrders': data['recentOrders'] ?? <dynamic>[],
            'hasMore': data['hasMore'] ?? false,
          };

          _cacheData(cacheKey, result);
          return result;
        }
      }

      return {
        'totalItemsSold': 0,
        'orderCount': 0,
        'recentOrders': <dynamic>[],
        'hasMore': false,
      };
    } catch (e) {
      print('Error fetching sales data: $e');
      return {
        'totalItemsSold': 0,
        'orderCount': 0,
        'recentOrders': <dynamic>[],
        'hasMore': false,
      };
    }
  }

  static Future<List<dynamic>> getMonthlyVisits(
      {required String userId}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/targets/monthly-visits/$userId'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception(
            'Failed to load monthly visits: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting monthly visits: $e');
      rethrow;
    }
  }
}
