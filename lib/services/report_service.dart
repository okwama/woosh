import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
<<<<<<< HEAD
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';
=======
import 'package:glamour_queen/models/report/report_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/utils/config.dart';
import 'package:glamour_queen/services/token_service.dart';
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

class ReportService {
  static const String baseUrl = '${Config.baseUrl}/api';
  static const Duration tokenExpirationDuration = Duration(hours: 5);

  static String? _getAuthToken() {
    return TokenService.getAccessToken();
  }

  static Future<Map<String, String>> _headers(
      [String? additionalContentType]) async {
    final token = _getAuthToken();
    print(
        'Preparing headers with token: ${token != null ? 'Token exists' : 'Token is null'}');
    final headers = {
      'Content-Type': additionalContentType ?? 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    print('Final headers: ${headers.toString()}');
    return headers;
  }

  Future<Report> submitReport(Report report) async {
    try {
      final token = _getAuthToken();
      print('=== Report Submission Debug ===');
      print('Auth Token Present: ${token != null}');
      print('Sales Rep ID from Report: ${report.salesRepId}');
      print('Journey Plan ID: ${report.journeyPlanId}');
      print('Client ID: ${report.clientId}');
      print('Report Type: ${report.type}');

      if (token == null) {
        print('ERROR: No auth token found');
        throw Exception('User is not authenticated');
      }

      // Validate required fields before submission
      if (report.journeyPlanId == null) {
        print('ERROR: Missing required fields');
        print('Sales Rep ID: ${report.salesRepId}');
        print('Client ID: ${report.clientId}');
        print('Journey Plan ID: ${report.journeyPlanId}');
        throw Exception('Missing required fields for report submission');
      }

      // Convert the report object to match backend's expected format
      final Map<String, dynamic> requestBody = {
        'type': report.type.toString().split('.').last,
        'journeyPlanId': report.journeyPlanId,
        'salesRepId': report.salesRepId,
        'clientId': report.clientId,
        'details': _getReportDetails(report),
      };

      print('Request Body: ${jsonEncode(requestBody)}');
      print('API Endpoint: $baseUrl/reports');

      final headers = await _headers();
      print('Request Headers: ${headers.toString()}');

      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 401) {
        print('ERROR: Authentication failed');
        throw Exception('Authentication failed. Please log in again.');
      }

      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        print('ERROR: API request failed');
        print('Error Data: $errorData');
        throw Exception(errorData['error'] ??
            'Failed to submit report: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (!data.containsKey('report') || !data.containsKey('specificReport')) {
        print('ERROR: Invalid response format');
        print('Response Data: $data');
        throw Exception('Invalid response format from server');
      }

      final mainReport = data['report'];
      final specificReport = data['specificReport'];
      mainReport['specificReport'] = specificReport;

      print('Report submission successful');
      print('=== End Report Submission Debug ===');

      return Report.fromJson(mainReport);
    } catch (e, stackTrace) {
      print('ERROR: Report submission failed');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      throw Exception('Failed to submit report: $e');
    }
  }

  // Helper method to extract report details based on type
  Map<String, dynamic> _getReportDetails(Report report) {
    try {
      switch (report.type) {
        case ReportType.PRODUCT_AVAILABILITY:
          if (report.productReport?.productName == null) {
            throw Exception(
                'Product name is required for product availability report');
          }
          return {
            'productName': report.productReport!.productName,
            'quantity': report.productReport?.quantity ?? 0,
            'comment': report.productReport?.comment ?? '',
          };
        case ReportType.VISIBILITY_ACTIVITY:
          return {
            'comment': report.visibilityReport?.comment ?? '',
            'imageUrl': report.visibilityReport?.imageUrl ?? '',
          };
        case ReportType.FEEDBACK:
          if (report.feedbackReport?.comment?.isEmpty ?? true) {
            throw Exception('Comment is required for feedback report');
          }
          return {
            'comment': report.feedbackReport!.comment,
          };
        default:
          throw Exception('Unknown report type: ${report.type}');
      }
    } catch (e) {
      print('ERROR: Failed to extract report details');
      print('Error: $e');
      rethrow;
    }
  }

  Future<List<Report>> getReports({
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
}
