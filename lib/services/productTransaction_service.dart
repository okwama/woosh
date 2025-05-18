import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';
import 'package:get_storage/get_storage.dart';

class ProductTransactionService {
  static const String baseUrl = '${Config.baseUrl}/api';

  static String? _getAuthToken() {
    final box = GetStorage();
    return box.read<String>('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch product reports with optional filters and caching
  static Future<List<ProductReport>> getProductReports({
    String? type, // RETURN or SAMPLE
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? clientId,
    int? userId,
  }) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (status != null) queryParams['status'] = status;
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (clientId != null) queryParams['clientId'] = clientId.toString();
      if (userId != null) queryParams['userId'] = userId.toString();

      final cacheKey =
          'product_reports_${type ?? ''}_${status ?? ''}_${startDate?.toIso8601String() ?? ''}_${endDate?.toIso8601String() ?? ''}_${clientId ?? ''}_${userId ?? ''}';
      final cachedData = ApiCache.get(cacheKey);
      if (cachedData != null) {
        return (cachedData as List)
            .map((json) => ProductReport.fromJson(json))
            .toList();
      }

      final uri = Uri.parse('$baseUrl/product-reports')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        ApiCache.set(cacheKey, data, validity: const Duration(minutes: 2));
        return data.map((json) => ProductReport.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load product reports: \\${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteProductReport(int id) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }
      final uri = Uri.parse('$baseUrl/product-reports/$id');
      final response = await http.delete(
        uri,
        headers: await _headers(),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateProductReportStatus(int id, String status) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }
      final uri = Uri.parse('$baseUrl/product-reports/$id/status');
      final response = await http.patch(
        uri,
        headers: await _headers(),
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<ProductReport?> getProductReportById(int id) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }
      final uri = Uri.parse('$baseUrl/product-reports/$id');
      final response = await http.get(
        uri,
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProductReport.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
