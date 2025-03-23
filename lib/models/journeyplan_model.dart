import 'package:whoosh/models/outlet_model.dart';
import 'package:flutter/material.dart';

class JourneyPlan {
  // Status constants
  static const int statusPending = 0;
  static const int statusCheckedIn = 1;
  static const int statusInProgress = 2;
  static const int statusCompleted = 3;
  static const int statusCancelled = 4;

  final int? id;
  final DateTime date;
  final String time;
  final int? userId;
  final int status; // 0 for pending, 1 for checked in
  final DateTime? checkInTime;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final Outlet outlet;

  JourneyPlan({
    this.id,
    required this.date,
    required this.time,
    this.userId,
    required this.status,
    this.checkInTime,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.outlet,
  });

  // Helper getters for status
  String get statusText {
    switch (status) {
      case statusPending:
        return 'Pending';
      case statusCheckedIn:
        return 'Checked In';
      case statusInProgress:
        return 'In Transit';
      case statusCompleted:
        return 'Completed';
      case statusCancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  bool get isCheckedIn => status == statusCheckedIn;
  bool get isPending => status == statusPending;
  bool get isInTransit => status == statusInProgress;
  bool get isCompleted => status == statusCompleted;
  bool get isCancelled => status == statusCancelled;

  // Helper getter for outletId
  int get outletId => outlet.id;

  // Helper method to get status color
  Color get statusColor {
    switch (status) {
      case statusPending:
        return Colors.orange;
      case statusCheckedIn:
        return Colors.blue;
      case statusInProgress:
        return Colors.purple;
      case statusCompleted:
        return Colors.green;
      case statusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to create a copy with updated status
  JourneyPlan copyWith({
    int? id,
    DateTime? date,
    String? time,
    int? userId,
    int? status,
    DateTime? checkInTime,
    double? latitude,
    double? longitude,
    String? imageUrl,
    Outlet? outlet,
  }) {
    return JourneyPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      outlet: outlet ?? this.outlet,
    );
  }

  factory JourneyPlan.fromJson(Map<String, dynamic> json) {
    if (json['date'] == null) {
      throw FormatException('Journey date is required');
    }
    if (json['outlet'] == null) {
      throw FormatException('Outlet information is required');
    }

    DateTime parseDate(String dateStr) {
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        throw FormatException('Invalid date format: $dateStr');
      }
    }

    // Extract time from date if not provided
    String getTime(DateTime date) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    }

    final date = parseDate(json['date']);
    final time = json['time'] ?? getTime(date);

    // Convert status to int, default to pending (0)
    final status = json['status'] != null
        ? (json['status'] is int
            ? json['status']
            : int.tryParse(json['status'].toString()) ?? statusPending)
        : statusPending;

    return JourneyPlan(
      id: json['id'],
      date: date,
      time: time,
      userId: json['userId'],
      status: status,
      checkInTime:
          json['checkInTime'] != null ? parseDate(json['checkInTime']) : null,
      latitude: json['latitude'] != null
          ? (json['latitude'] is double
              ? json['latitude']
              : double.tryParse(json['latitude'].toString()))
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] is double
              ? json['longitude']
              : double.tryParse(json['longitude'].toString()))
          : null,
      imageUrl: json['imageUrl'],
      outlet: Outlet.fromJson(json['outlet']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time,
      'userId': userId,
      'status': status,
      'checkInTime': checkInTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'outlet': outlet.toJson(),
    };
  }
}
