import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';

class RouteService {
  static const String baseUrl = Config.baseUrl;

  static String? _getAuthToken() {
    return TokenService.getAccessToken();
  }

  static Future<Map<String, String>> _headers() async {
    final token = _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch available routes for journey planning
  static Future<List<Map<String, dynamic>>> fetchRoutes() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final url = Uri.parse('$baseUrl/routes');
      print('🔍 Fetching routes from: $url');
      print('🔍 Token present: ${token != null}');

      final response = await http.get(
        url,
        headers: await _headers(),
      );

      print('🔍 Routes response status: ${response.statusCode}');
      print('🔍 Routes response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🔍 Routes fetched successfully: ${data.length} routes');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Failed to fetch routes: ${response.statusCode}');
        throw Exception('Failed to fetch routes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching routes: $e');
      // Return empty list as fallback
      return [];
    }
  }

  /// Get route by ID
  static Future<Map<String, dynamic>?> getRouteById(int routeId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/routes/$routeId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching route: $e');
      return null;
    }
  }

  /// Create a new route
  static Future<Map<String, dynamic>> createRoute(
      Map<String, dynamic> routeData) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: await _headers(),
        body: jsonEncode(routeData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to create route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating route: $e');
      rethrow;
    }
  }

  /// Update an existing route
  static Future<Map<String, dynamic>> updateRoute(
      int routeId, Map<String, dynamic> routeData) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/routes/$routeId'),
        headers: await _headers(),
        body: jsonEncode(routeData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to update route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating route: $e');
      rethrow;
    }
  }

  /// Delete a route
  static Future<bool> deleteRoute(int routeId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/routes/$routeId'),
        headers: await _headers(),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting route: $e');
      return false;
    }
  }
}
