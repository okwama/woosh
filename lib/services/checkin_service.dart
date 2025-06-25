import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/utils/config.dart';
import 'package:glamour_queen/services/token_service.dart';

class CheckInService {
  static const String _baseUrl = '${Config.baseUrl}/api';
  static final _storage = GetStorage();
  static const _defaultTimeout = Duration(seconds: 15);

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'Timezone': DateTime.now().timeZoneName, // Send client timezone
    };
  }

  static Future<Map<String, double>> getOutletLocation(int outletId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/outlets/$outletId/location'),
            headers: await _getAuthHeaders(),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'latitude': (data['latitude'] as num).toDouble(),
          'longitude': (data['longitude'] as num).toDouble(),
        };
      }
      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception(
          'Failed to fetch outlet location: ${_getErrorMessage(e)}');
    }
  }

  static Future<Map<String, dynamic>> checkIn({
    required int outletId,
    required double latitude,
    required double longitude,
    String? notes,
    String? imagePath,
  }) async {
    try {
      final request = {
        'outletId': outletId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
        if (notes != null) 'notes': notes,
        if (imagePath != null) 'imagePath': imagePath,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/manager/check-in'),
            headers: await _getAuthHeaders(),
            body: jsonEncode(request),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Check-in failed: ${_getErrorMessage(e)}');
    }
  }

  static Future<Map<String, dynamic>> checkOut({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final request = {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/manager/check-out'),
            headers: await _getAuthHeaders(),
            body: jsonEncode(request),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Check-out failed: ${_getErrorMessage(e)}');
    }
  }

  static Future<CheckInStatus> getTodayStatus() async {
    int retries = 3;
    final urls = [
      '$_baseUrl/manager/today-status',
      '${Config.baseUrl}/api/manager/today-status',
    ];

    while (retries > 0) {
      try {
        final urlToUse = urls[retries % urls.length];
        final response = await http
            .get(
              Uri.parse(urlToUse),
              headers: await _getAuthHeaders(),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          if (response.body.isEmpty) return CheckInStatus.empty();
          return CheckInStatus.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>);
        }
        return CheckInStatus.empty();
      } catch (e) {
        retries--;
        if (retries == 0) {
          return CheckInStatus.empty();
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }
    return CheckInStatus.empty();
  }

  static Future<PaginatedCheckIns> getCheckInHistory({
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final response = await http
          .get(
            Uri.parse('$_baseUrl/manager/history')
                .replace(queryParameters: params),
            headers: await _getAuthHeaders(),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return PaginatedCheckIns.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw _handleErrorResponse(response);
    } catch (e) {
      throw Exception('Failed to load history: ${_getErrorMessage(e)}');
    }
  }

  // Helper methods
  static Exception _handleErrorResponse(http.Response response) {
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return Exception(error['message'] ??
          'Request failed with status ${response.statusCode}');
    } catch (_) {
      return Exception('Request failed with status ${response.statusCode}');
    }
  }

  static String _getErrorMessage(dynamic error) {
    if (error is TimeoutException) return 'Request timed out';
    if (error is http.ClientException) return 'Network error';
    return error.toString();
  }
}

// Improved model classes with better null safety
class CheckInStatus {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? outletId;
  final String? outletName;
  final int? visitNumber;

  const CheckInStatus({
    this.isCheckedIn = false,
    this.checkInTime,
    this.checkOutTime,
    this.outletId,
    this.outletName,
    this.visitNumber,
  });

  factory CheckInStatus.empty() => const CheckInStatus();

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      isCheckedIn: json['isCheckedIn'] as bool? ?? false,
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'] as String)
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      outletId: json['outletId'] as int?,
      outletName: json['outletName'] as String?,
      visitNumber: json['visitNumber'] as int?,
    );
  }
}

class PaginatedCheckIns {
  final List<CheckInRecord> records;
  final int currentPage;
  final int totalPages;
  final int totalRecords;

  const PaginatedCheckIns({
    required this.records,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  factory PaginatedCheckIns.fromJson(Map<String, dynamic> json) {
    return PaginatedCheckIns(
      records: (json['data'] as List)
          .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
      totalRecords: json['totalRecords'] as int,
    );
  }
}

class CheckInRecord {
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String outletName;
  final String outletAddress;
  final int visitNumber;
  final String? imageUrl;

  const CheckInRecord({
    required this.checkInTime,
    this.checkOutTime,
    required this.outletName,
    required this.outletAddress,
    this.visitNumber = 1,
    this.imageUrl,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      checkInTime: DateTime.parse(json['checkInTime'] as String),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      outletName: json['outletName'] as String,
      outletAddress: json['outletAddress'] as String,
      visitNumber: json['visitNumber'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
