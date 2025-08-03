import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/shared_data_service.dart';
import 'package:woosh/services/token_service.dart';

class ReportsService {
  static const String _baseUrl = ApiService.baseUrl;

  static String? _getAuthToken() {
    try {
      return TokenService.getAccessToken();
    } catch (e) {
      print('Error reading token from storage: $e');
      return null;
    }
  }

  /// Submit a report to the backend
  static Future<void> submitReport(Report report) async {
    try {
      final url = Uri.parse('$_baseUrl/reports');

      // Convert report to JSON
      final reportData = report.toJson();

      // Get auth token
      final token = _getAuthToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      final url = Uri.parse('$_baseUrl/reports/journey-plan/$journeyPlanId');
      final token = _getAuthToken();
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
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
}
