import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/models/client_stock_model.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';

class ClientStockService {
  static const String baseUrl = '${Config.baseUrl}/api/client-stock';

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

  /// Update or create client stock entry for a specific product
  static Future<Map<String, dynamic>> updateStock({
    required int clientId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await _headers(),
        body: json.encode({
          'clientId': clientId,
          'productId': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'message':
                responseData['message'] ?? 'Client stock updated successfully',
            'data': responseData['data'],
          };
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to update client stock');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ??
            'Failed to update client stock: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating client stock: $e');
      throw Exception('Failed to update client stock: $e');
    }
  }

  /// Get all stock entries for a specific client
  static Future<List<ClientStock>> getClientStock(int clientId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$clientId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => ClientStock.fromJson(json)).toList();
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to get client stock');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ??
            'Failed to get client stock: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting client stock: $e');
      throw Exception('Failed to get client stock: $e');
    }
  }

  /// Check if client stock feature is enabled
  static Future<bool> isFeatureEnabled() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['enabled'] ?? true;
      } else if (response.statusCode == 404) {
        // Status endpoint doesn't exist, assume feature is enabled
        return true;
      }
      return true; // Default to enabled
    } catch (e) {
      print('Error checking client stock feature status: $e');
      return true; // Default to enabled on any error
    }
  }
}
