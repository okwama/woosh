import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/utils/config.dart';
import 'dart:io';

class CheckInService {
  static const String _baseUrl = '${Config.baseUrl}/api';
  static final _storage = GetStorage();

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = _storage.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, double>> getOutletLocation(int outletId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/outlets/$outletId/location'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'latitude': data['latitude']?.toDouble() ?? 0.0,
          'longitude': data['longitude']?.toDouble() ?? 0.0,
        };
      }
      throw Exception('Failed to fetch outlet location');
    } catch (e) {
      throw Exception('Location fetch failed: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> checkIn({
    required int outletId,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/manager/check-in'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'outletId': outletId,
          'latitude': latitude,
          'longitude': longitude,
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

  static CheckInStatus _createSafeStatus(dynamic data) {
    if (data == null) return CheckInStatus(isCheckedIn: false);

    if (data is String) {
      try {
        final bool value = data.toLowerCase() == 'true';
        return CheckInStatus(isCheckedIn: value);
      } catch (_) {
        return CheckInStatus(isCheckedIn: false);
      }
    }

    if (data is Map<String, dynamic>) {
      try {
        return CheckInStatus.fromJson(data);
      } catch (_) {
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
            outletId: data['outletId'] != null
                ? int.tryParse(data['outletId'].toString())
                : null,
            outletName: data['outletName']?.toString(),
          );
        } catch (_) {
          return CheckInStatus(isCheckedIn: false);
        }
      }
    }

    return CheckInStatus(isCheckedIn: false);
  }

  static Future<CheckInStatus> getTodayStatus() async {
    int retries = 3;

    while (retries > 0) {
      try {
        final token = _storage.read<String>('token');
        if (token == null) {
          return CheckInStatus(isCheckedIn: false);
        }

        final urls = [
          '$_baseUrl/manager/today-status',
          '${Config.baseUrl}/api/manager/today-status',
        ];

        final urlToUse = urls[3 - retries];
        final headers = await _getAuthHeaders();

        final response = await http
            .get(
          Uri.parse(urlToUse),
          headers: headers,
        )
            .timeout(Duration(seconds: 10), onTimeout: () {
          throw TimeoutException('Request timed out');
        });

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            return CheckInStatus(isCheckedIn: false);
          }

          try {
            final data = jsonDecode(response.body);
            return _createSafeStatus(data);
          } catch (_) {
            return _createSafeStatus(response.body);
          }
        } else {
          return CheckInStatus(isCheckedIn: false);
        }
      } catch (_) {
        retries--;
        if (retries > 0) {
          await Future.delayed(Duration(seconds: 1));
        } else {
          return CheckInStatus(isCheckedIn: false);
        }
      }
    }

    return CheckInStatus(isCheckedIn: false);
  }

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
  final int? outletId;
  final String? outletName;

  CheckInStatus({
    this.isCheckedIn = false,
    this.checkInTime,
    this.outletId,
    this.outletName,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
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
      outletId: json['outletId'],
      outletName: json['outletName'],
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
  final String outletName;
  final String outletAddress;

  CheckInRecord({
    required this.checkInTime,
    this.checkOutTime,
    required this.outletName,
    required this.outletAddress,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      checkInTime: DateTime.parse(json['checkInTime']),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'])
          : null,
      outletName: json['outletName'],
      outletAddress: json['outletAddress'],
    );
  }
}
