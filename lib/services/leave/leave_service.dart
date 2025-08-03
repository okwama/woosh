import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/leave_model.dart';
import 'package:woosh/services/token_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:woosh/utils/config.dart';

class LeaveService {
  static String get baseUrl => Config.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = TokenService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Submit leave application
  static Future<Leave> submitLeaveApplication({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    dynamic attachmentFile, // Accepts File for mobile, Uint8List for web
  }) async {
    try {
      print('Submitting leave application with data:');
      print('leaveType: $leaveType');
      print('startDate: $startDate');
      print('endDate: $endDate');
      print('reason: $reason');
      print('attachment: ${attachmentFile != null ? "Yes" : "No file"}');

      final uri = Uri.parse('$baseUrl/leave');

      // Handle request when no attachment is present
      if (attachmentFile == null) {
        final response = await http.post(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            'leaveType': leaveType,
            'startDate': startDate,
            'endDate': endDate,
            'reason': reason,
          }),
        );

        print('Leave API Response Status: ${response.statusCode}');
        print('Leave API Response Body: ${response.body}');

        if (response.statusCode == 201) {
          return Leave.fromJson(jsonDecode(response.body));
        } else {
          final responseBody = jsonDecode(response.body);
          final errorMessage = responseBody['error'] ??
              responseBody['message'] ??
              'Failed to submit leave application';
          throw Exception(errorMessage);
        }
      } else {
        // Handle Multipart File Upload
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(await _headers());

        request.fields['leaveType'] = leaveType;
        request.fields['startDate'] = startDate;
        request.fields['endDate'] = endDate;
        request.fields['reason'] = reason;

        // Handle different file types based on platform
        if (kIsWeb) {
          print('Web file upload: Adding bytes to multipart request');
          // Web file upload (bytes)
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              attachmentFile,
              filename:
                  'web_document_${DateTime.now().millisecondsSinceEpoch}.jpg',
              contentType: MediaType('application', 'octet-stream'),
            ),
          );
        } else {
          print('Mobile file upload: Adding file from path');
          // Mobile/desktop file upload (File object)
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachment',
              attachmentFile.path,
              filename: attachmentFile.path.split('/').last,
            ),
          );
        }

        print('Sending multipart request for leave application');
        final streamedResponse = await request.send();
        print('Response status code: ${streamedResponse.statusCode}');

        final response = await http.Response.fromStream(streamedResponse);
        print('Leave API Response Status: ${response.statusCode}');
        print('Leave API Response Body: ${response.body}');

        if (response.statusCode == 201) {
          return Leave.fromJson(jsonDecode(response.body));
        } else {
          final responseBody = jsonDecode(response.body);
          final errorMessage = responseBody['error'] ??
              responseBody['message'] ??
              'Failed to submit leave application';
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      print('Error in submitLeaveApplication: $e');
      rethrow;
    }
  }

  // Get user's leave applications
  static Future<List<Leave>> getUserLeaves() async {
    try {
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      final salesRepId = salesRep?['id']?.toString();

      if (salesRepId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/leave?userId=$salesRepId'),
        headers: await _headers(),
      );

      print('Leave API Response Status: ${response.statusCode}');
      print('Leave API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        // Handle different response structures
        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format: $responseData');
        }

        return data.map((json) {
          try {
            return Leave.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing leave item: $e');
            print('Leave item data: $json');
            rethrow;
          }
        }).toList();
      } else {
        throw Exception('Failed to fetch leave applications: ${response.body}');
      }
    } catch (e) {
      print('Error in getUserLeaves: $e');
      rethrow;
    }
  }

  // Get all leave applications (admin only)
  static Future<List<Leave>> getAllLeaves() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Leave.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch all leave applications');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update leave status (admin only)
  static Future<Leave> updateLeaveStatus(
      int leaveId, LeaveStatus status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/leave/$leaveId'),
        headers: await _headers(),
        body: jsonEncode({'status': status.toString().split('.').last}),
      );

      if (response.statusCode == 200) {
        return Leave.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update leave status');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get leave types
  static Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave/types/all'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch leave types');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get leave balance
  static Future<Map<String, dynamic>> getLeaveBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave/balance/user'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch leave balance');
      }
    } catch (e) {
      rethrow;
    }
  }
}
