import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';

class ReportsService {
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

  /// Submit a report to the backend
  static Future<void> submitReport(Report report) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Convert report to JSON
      final reportData = report.toJson();

      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: await _headers(),
        body: jsonEncode(reportData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Report submitted successfully');
      } else {
        throw Exception(
            'Failed to submit report: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error submitting report: $e');
      rethrow;
    }
  }

  /// Get reports by journey plan ID
  static Future<Map<String, dynamic>> getReportsByJourneyPlan(
      int journeyPlanId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/reports/journey-plan/$journeyPlanId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to get reports: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting reports: $e');
      rethrow;
    }
  }

  /// Get all reports with optional filters
  static Future<List<Report>> getReports({
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
      if (journeyPlanId != null) {
        queryParams['journeyPlanId'] = journeyPlanId.toString();
      }
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

  /// Get report by ID
  static Future<Report?> getReportById(int reportId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/reports/$reportId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Report.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to fetch report: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching report: $e');
      return null;
    }
  }

  /// Delete a report
  static Future<bool> deleteReport(int reportId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/reports/$reportId'),
        headers: await _headers(),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting report: $e');
      return false;
    }
  }
}
