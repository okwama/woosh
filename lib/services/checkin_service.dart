import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/utils/config.dart';
import 'dart:io';

class CheckInService {
  static const String _baseUrl = '${Config.baseUrl}/api';
  static final _storage = GetStorage();

  /// Helper to get auth headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = _storage.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Verify office QR code validity
  static Future<bool> verifyQRCode(String qrCode, int officeId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/manager/verify-qr'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'qrCode': qrCode,
          'officeId': officeId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isValid'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get office location coordinates
  static Future<Map<String, double>> getOfficeLocation(int officeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/offices/$officeId/location'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'latitude': data['latitude']?.toDouble() ?? 0.0,
          'longitude': data['longitude']?.toDouble() ?? 0.0,
        };
      }
      throw Exception('Failed to fetch office location');
    } catch (e) {
      throw Exception('Location fetch failed: ${e.toString()}');
    }
  }

  /// Handle manager check-in with QR validation
  static Future<Map<String, dynamic>> checkIn({
    required int officeId,
    required double latitude,
    required double longitude,
    required String qrCodeHash,
    String? notes,
  }) async {
    try {
      // First verify the QR code
      final isValid = await verifyQRCode(qrCodeHash, officeId);
      if (!isValid) {
        throw Exception('Invalid QR code for this office');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/manager/check-in'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'officeId': officeId,
          'latitude': latitude,
          'longitude': longitude,
          'qrCodeHash': qrCodeHash,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to check in');
      }
    } catch (e) {
      throw Exception('Check-in failed: ${e.toString()}');
    }
  }

  /// Handle manager check-out
  static Future<Map<String, dynamic>> checkOut() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/manager/check-out'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to check out');
      }
    } catch (e) {
      throw Exception('Check-out failed: ${e.toString()}');
    }
  }

  /// Create a safe CheckInStatus object from any response
  static CheckInStatus _createSafeStatus(dynamic data) {
    if (data == null) {
      print('⚠️ Data is null, returning default status');
      return CheckInStatus(isCheckedIn: false);
    }

    // For raw strings like "true" or "false"
    if (data is String) {
      print('⚠️ Data is a string: $data');
      try {
        final bool value = data.toLowerCase() == 'true';
        return CheckInStatus(isCheckedIn: value);
      } catch (e) {
        print('❌ Error parsing string data: $e');
        return CheckInStatus(isCheckedIn: false);
      }
    }

    // For maps/json objects
    if (data is Map<String, dynamic>) {
      print('✅ Data is a Map, using fromJson');
      try {
        return CheckInStatus.fromJson(data);
      } catch (e) {
        print('❌ Error creating CheckInStatus from Map: $e');

        // If the error is in parsing isCheckedIn, try a direct approach
        try {
          final dynamic rawValue = data['isCheckedIn'];
          final bool isCheckedIn = rawValue is bool
              ? rawValue
              : rawValue != null
                  ? true
                  : false;

          return CheckInStatus(
            isCheckedIn: isCheckedIn,
            checkInTime: data['checkInTime'] != null
                ? DateTime.parse(data['checkInTime'])
                : null,
            officeId: data['officeId'] != null
                ? int.tryParse(data['officeId'].toString())
                : null,
            officeName: data['officeName']?.toString(),
          );
        } catch (e2) {
          print('❌ Second attempt also failed: $e2');
          return CheckInStatus(isCheckedIn: false);
        }
      }
    }

    print('⚠️ Unknown data type: ${data.runtimeType}');
    return CheckInStatus(isCheckedIn: false);
  }

  /// Get today's check-in status with shift details - improved with timeout and retries
  static Future<CheckInStatus> getTodayStatus() async {
    int retries = 3;

    while (retries > 0) {
      try {
        print('📊 Starting getTodayStatus... (retries left: $retries)');
        final token = _storage.read<String>('token');
        if (token == null) {
          print('❌ No token found, returning default status');
          return CheckInStatus(isCheckedIn: false);
        }

        // Try different URL formats to see which one works
        final urls = [
          '$_baseUrl/manager/today-status',
          '${Config.baseUrl}/api/manager/today-status',
        ];

        final urlToUse =
            urls[3 - retries]; // Use a different URL format for each retry
        print('🔄 Making API request to $urlToUse');

        final headers = await _getAuthHeaders();
        print('🔑 Using headers: $headers');

        // Use a timeout to avoid hanging
        final response = await http
            .get(
          Uri.parse(urlToUse),
          headers: headers,
        )
            .timeout(Duration(seconds: 10), onTimeout: () {
          print('⏱️ Request timed out');
          throw TimeoutException('Request timed out');
        });

        print('📩 Response status: ${response.statusCode}');
        print('📩 Response body: ${response.body}');

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            print('⚠️ Response body is empty');
            return CheckInStatus(isCheckedIn: false);
          }

          try {
            // Try to decode as JSON first
            final data = jsonDecode(response.body);
            print('🔍 Decoded JSON: $data');

            // Use our safe creation method
            return _createSafeStatus(data);
          } catch (e) {
            print('❌ JSON parsing error: $e');

            // If JSON fails, try to use the raw response
            return _createSafeStatus(response.body);
          }
        } else {
          print('❌ HTTP error: ${response.statusCode}');
          return CheckInStatus(isCheckedIn: false);
        }
      } catch (e) {
        print('❌ Status check failed: ${e.toString()}');
        retries--;

        if (retries > 0) {
          print('🔄 Retrying...');
          await Future.delayed(Duration(seconds: 1));
        } else {
          return CheckInStatus(isCheckedIn: false);
        }
      }
    }

    return CheckInStatus(isCheckedIn: false);
  }

  /// Get check-in history with pagination
  static Future<PaginatedCheckIns> getCheckInHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/history?page=$page&limit=$limit'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PaginatedCheckIns.fromJson(data);
      }
      throw Exception('Failed to load history');
    } catch (e) {
      throw Exception('History load failed: ${e.toString()}');
    }
  }
}

class CheckInStatus {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final int? officeId;
  final String? officeName;

  CheckInStatus({
    this.isCheckedIn = false,
    this.checkInTime,
    this.officeId,
    this.officeName,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    // Handle various possible types for isCheckedIn
    bool parseIsCheckedIn() {
      final value = json['isCheckedIn'];
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    return CheckInStatus(
      isCheckedIn: parseIsCheckedIn(),
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      officeId: json['officeId'],
      officeName: json['officeName'],
    );
  }
}

class PaginatedCheckIns {
  final List<CheckInRecord> records;
  final int currentPage;
  final int totalPages;
  final int totalRecords;

  PaginatedCheckIns({
    required this.records,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  factory PaginatedCheckIns.fromJson(Map<String, dynamic> json) {
    return PaginatedCheckIns(
      records:
          (json['data'] as List).map((e) => CheckInRecord.fromJson(e)).toList(),
      currentPage: json['currentPage'],
      totalPages: json['totalPages'],
      totalRecords: json['totalRecords'],
    );
  }
}

class CheckInRecord {
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String officeName;
  final String officeAddress;

  CheckInRecord({
    required this.checkInTime,
    this.checkOutTime,
    required this.officeName,
    required this.officeAddress,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      checkInTime: DateTime.parse(json['checkInTime']),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'])
          : null,
      officeName: json['officeName'],
      officeAddress: json['officeAddress'],
    );
  }
}
