import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/models/target_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';

class TargetService {
  static const String baseUrl = '${Config.baseUrl}/api';
  static const Duration _cacheDuration = Duration(minutes: 5);
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Get auth token for API requests
  static String? _getAuthToken() {
    final box = GetStorage();
    return box.read<String>('token');
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

  // Get all targets for the current user
  static Future<List<Target>> getTargets({
    int page = 1,
    int limit = 10,
  }) async {
    final cacheKey = 'targets_page_$page';
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

      final response = await http
          .get(
            Uri.parse('$baseUrl/targets?page=$page&limit=$limit'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Expect a list of targets with achievedValue and progress from backend
        final targets = (data as List)
            .map((item) => Target.fromJson(item))
            .toList();
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
  }) async {
    final cacheKey = 'sales_data_page_$page';
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

      final response = await http.get(
        Uri.parse(
            '$baseUrl/orders/sales-summary?days=14&page=$page&limit=$limit'),
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
}
