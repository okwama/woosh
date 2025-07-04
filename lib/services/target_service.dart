import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/models/target_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/targets/sales_rep_dashboard.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';

/// Custom exception for targets API errors
class TargetsApiException implements Exception {
  final String message;
  final int? statusCode;

  TargetsApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'TargetsApiException: $message (Status: $statusCode)';
}

class TargetService {
  static const String baseUrl = '${Config.baseUrl}/api';
  static const Duration _cacheDuration =
      Duration(minutes: 10); // Increased cache duration
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache keys for different data types
  static const String _dashboardCachePrefix = 'dashboard';
  static const String _newClientsCachePrefix = 'new_clients';
  static const String _productSalesCachePrefix = 'product_sales';
  static const String _clientDetailsCachePrefix = 'client_details';
  static const String _dailyVisitsCachePrefix = 'daily_visits';
  static const String _targetsCachePrefix = 'targets';
  static const String _salesDataCachePrefix = 'sales_data';

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

  /// Get comprehensive dashboard for sales rep
  static Future<SalesRepDashboard> getDashboard(
    int userId, {
    String period = 'current_month',
  }) async {
    final cacheKey = 'dashboard_${userId}_$period';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData as SalesRepDashboard;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      final url = '$baseUrl/targets/dashboard/$userId?period=$period';
      print('Debug - Making dashboard API call to: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      print('Debug - Dashboard response status: ${response.statusCode}');
      print('Debug - Dashboard response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dashboard = SalesRepDashboard.fromJson(data);
        _cacheData(cacheKey, dashboard);
        return dashboard;
      } else if (response.statusCode == 404) {
        throw TargetsApiException('Sales rep not found', 404);
      } else if (response.statusCode == 401) {
        throw TargetsApiException('Unauthorized access', 401);
      } else {
        throw TargetsApiException(
            'Failed to load dashboard', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      print('Debug - Error in getDashboard: $e');
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Get new clients progress
  static Future<NewClientsProgress> getNewClientsProgress(
    int userId, {
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    final cacheKey = 'new_clients_${userId}_${period}_${startDate}_$endDate';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData as NewClientsProgress;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      String url = '$baseUrl/targets/clients/$userId/progress';
      List<String> params = [];

      if (period != null) params.add('period=$period');
      if (startDate != null) params.add('startDate=$startDate');
      if (endDate != null) params.add('endDate=$endDate');

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final progress = NewClientsProgress.fromJson(data);
        _cacheData(cacheKey, progress);
        return progress;
      } else {
        throw TargetsApiException(
            'Failed to load new clients progress', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Get product sales progress (vapes and pouches)
  static Future<ProductSalesProgress> getProductSalesProgress(
    int userId, {
    String productType = 'all',
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    final cacheKey =
        'product_sales_${userId}_${productType}_${period}_${startDate}_$endDate';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData as ProductSalesProgress;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      String url = '$baseUrl/targets/products/$userId/progress';
      List<String> params = ['productType=$productType'];

      if (period != null) params.add('period=$period');
      if (startDate != null) params.add('startDate=$startDate');
      if (endDate != null) params.add('endDate=$endDate');

      url += '?${params.join('&')}';

      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final progress = ProductSalesProgress.fromJson(data);
        _cacheData(cacheKey, progress);
        return progress;
      } else {
        throw TargetsApiException(
            'Failed to load product sales progress', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Get category mapping for product classification
  static Future<Map<String, dynamic>> getCategoryMapping() async {
    const cacheKey = 'category_mapping';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData as Map<String, dynamic>;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      final url = '$baseUrl/targets/categories/mapping';
      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cacheData(cacheKey, data);
        return data;
      } else {
        throw TargetsApiException(
            'Failed to load category mapping', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Get client details for new clients
  static Future<Map<String, dynamic>> getClientDetails(
    int userId, {
    String? period,
  }) async {
    final cacheKey = 'client_details_${userId}_$period';
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData as Map<String, dynamic>;
    }

    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      String url = '$baseUrl/targets/clients/$userId/details';
      List<String> params = [];

      if (period != null) params.add('period=$period');

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cacheData(cacheKey, data);
        return data;
      } else {
        throw TargetsApiException(
            'Failed to load client details', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Update sales rep targets
  static Future<Map<String, dynamic>> updateSalesRepTargets(
    int userId, {
    int? vapesTargets,
    int? pouchesTargets,
    int? newClientsTarget,
    int? visitsTargets,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw TargetsApiException('No authentication token found', 401);
      }

      final url = '$baseUrl/targets/targets/$userId';
      Map<String, dynamic> body = {};

      if (vapesTargets != null) body['vapes_targets'] = vapesTargets;
      if (pouchesTargets != null) body['pouches_targets'] = pouchesTargets;
      if (newClientsTarget != null) {
        body['new_clients_target'] = newClientsTarget;
      }
      if (visitsTargets != null) body['visits_targets'] = visitsTargets;

      final response = await http
          .put(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Smart cache invalidation based on what was updated
        _invalidateCacheForTargetUpdate(
          userId,
          vapesTargets: vapesTargets,
          pouchesTargets: pouchesTargets,
          newClientsTarget: newClientsTarget,
          visitsTargets: visitsTargets,
        );
        return data;
      } else {
        throw TargetsApiException(
            'Failed to update targets', response.statusCode);
      }
    } catch (e) {
      if (e is TargetsApiException) rethrow;
      throw TargetsApiException('Network error: ${e.toString()}');
    }
  }

  /// Smart cache invalidation for target updates
  static void _invalidateCacheForTargetUpdate(
    int userId, {
    int? vapesTargets,
    int? pouchesTargets,
    int? newClientsTarget,
    int? visitsTargets,
  }) {
    // Always clear dashboard cache as it aggregates all data
    clearDashboardCache(userId);

    // Clear specific caches based on what was updated
    if (vapesTargets != null || pouchesTargets != null) {
      clearProductSalesCache(userId);
    }

    if (newClientsTarget != null) {
      clearNewClientsCache(userId);
      clearClientDetailsCache(userId);
    }

    if (visitsTargets != null) {
      clearDailyVisitsCache(userId.toString());
    }

    print('Debug - Smart cache invalidation completed for user: $userId');
  }

  /// Clear cache entries with specific prefix
  static void _clearCacheWithPrefix(String prefix) {
    final keysToRemove =
        _cache.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
    print(
        'Debug - Cleared cache for prefix: $prefix (${keysToRemove.length} entries)');
  }

  /// Clear all cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('Debug - Cleared all cache');
  }

  /// Clear specific data type cache
  static void clearDashboardCache(int userId) {
    _clearCacheWithPrefix('${_dashboardCachePrefix}_$userId');
  }

  static void clearNewClientsCache(int userId) {
    _clearCacheWithPrefix('${_newClientsCachePrefix}_$userId');
  }

  static void clearProductSalesCache(int userId) {
    _clearCacheWithPrefix('${_productSalesCachePrefix}_$userId');
  }

  static void clearClientDetailsCache(int userId) {
    _clearCacheWithPrefix('${_clientDetailsCachePrefix}_$userId');
  }

  static void clearDailyVisitsCache(String userId) {
    _clearCacheWithPrefix('${_dailyVisitsCachePrefix}_$userId');
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'totalEntries': _cache.length,
      'cacheKeys': _cache.keys.toList(),
      'oldestEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : null,
      'newestEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String()
          : null,
    };
  }

  /// Preload common data for better performance
  static Future<void> preloadUserData(int userId) async {
    try {
      print('Debug - Preloading data for user: $userId');

      // Preload dashboard data for current month
      await getDashboard(userId, period: 'current_month');

      // Preload new clients progress
      await getNewClientsProgress(userId, period: 'current_month');

      // Preload product sales progress
      await getProductSalesProgress(userId, period: 'current_month');

      // Preload daily visits for today
      final today = DateTime.now();
      final formattedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await getDailyVisitTargets(
          userId: userId.toString(), date: formattedDate);

      print('Debug - Preloading completed for user: $userId');
    } catch (e) {
      print('Debug - Error preloading data: $e');
    }
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

  // Get all targets for the current user with enhanced caching
  static Future<List<Target>> getTargets({
    int page = 1,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? type,
  }) async {
    // Create a comprehensive cache key that includes all filter parameters
    final cacheKey = _buildTargetsCacheKey(
      page: page,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
      status: status,
      type: type,
    );

    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      print('Debug - Using cached targets data for key: $cacheKey');
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
      if (status != null) {
        queryParams['status'] = status;
      }
      if (type != null) {
        queryParams['type'] = type;
      }

      final uri =
          Uri.parse('$baseUrl/targets').replace(queryParameters: queryParams);

      print('Debug - Fetching targets with params: $queryParams');

      final response = await http
          .get(
            uri,
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final targets =
            (data as List).map((item) => Target.fromJson(item)).toList();
        _cacheData(cacheKey, targets);
        print(
            'Debug - Cached targets data for key: $cacheKey (${targets.length} items)');
        return targets;
      }
      return [];
    } catch (e) {
      print('Error fetching targets: $e');
      return [];
    }
  }

  /// Build cache key for targets with filters
  static String _buildTargetsCacheKey({
    required int page,
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? type,
  }) {
    final parts = [
      _targetsCachePrefix,
      'page_$page',
      'limit_$limit',
      if (startDate != null) 'start_${startDate.toIso8601String()}',
      if (endDate != null) 'end_${endDate.toIso8601String()}',
      if (status != null) 'status_$status',
      if (type != null) 'type_$type',
    ];
    return parts.join('_');
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newTarget = Target.fromJson(data);

        // Clear targets cache since we added a new target
        _clearCacheWithPrefix(_targetsCachePrefix);
        print('Debug - Cleared targets cache after creating new target');

        return newTarget;
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedTarget = Target.fromJson(data);

        // Clear targets cache since we updated a target
        _clearCacheWithPrefix(_targetsCachePrefix);
        print('Debug - Cleared targets cache after updating target');

        return updatedTarget;
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Clear targets cache since we deleted a target
        _clearCacheWithPrefix(_targetsCachePrefix);
        print('Debug - Cleared targets cache after deleting target');
        return true;
      }
      return false;
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
        headers: await _headers(),
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

  /// Bulk cache operations for better performance
  static void clearAllUserCache(int userId) {
    clearDashboardCache(userId);
    clearNewClientsCache(userId);
    clearProductSalesCache(userId);
    clearClientDetailsCache(userId);
    clearDailyVisitsCache(userId.toString());
    print('Debug - Cleared all cache for user: $userId');
  }

  /// Clear cache for specific data types across all users
  static void clearAllDashboardCache() {
    _clearCacheWithPrefix(_dashboardCachePrefix);
  }

  static void clearAllTargetsCache() {
    _clearCacheWithPrefix(_targetsCachePrefix);
  }

  static void clearAllSalesDataCache() {
    _clearCacheWithPrefix(_salesDataCachePrefix);
  }

  /// Force refresh specific data (bypass cache)
  static Future<SalesRepDashboard> forceRefreshDashboard(
    int userId, {
    String period = 'current_month',
  }) async {
    final cacheKey = 'dashboard_${userId}_$period';
    _cache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    return await getDashboard(userId, period: period);
  }

  static Future<NewClientsProgress> forceRefreshNewClients(
    int userId, {
    String? period,
  }) async {
    final cacheKey = 'new_clients_${userId}_$period';
    _cache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    return await getNewClientsProgress(userId, period: period);
  }

  static Future<ProductSalesProgress> forceRefreshProductSales(
    int userId, {
    String period = 'current_month',
  }) async {
    final cacheKey = 'product_sales_${userId}_$period';
    _cache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    return await getProductSalesProgress(userId, period: period);
  }
}
