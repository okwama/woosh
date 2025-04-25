import 'package:woosh/models/client_model.dart';
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
  final int? salesRepId;
  final int status; // 0 for pending, 1 for checked in
  final String? notes;
  final DateTime? checkInTime;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final Client client;
  final DateTime? checkoutTime;
  final double? checkoutLatitude;
  final double? checkoutLongitude;

  JourneyPlan({
    this.id,
    required this.date,
    required this.time,
    this.salesRepId,
    required this.status,
    this.checkInTime,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.client,
    this.notes,
    this.checkoutTime,
    this.checkoutLatitude,
    this.checkoutLongitude,
  });

  // Helper getters for status
  String get statusText {
    switch (status) {
      case statusPending:
        return 'Pending';
      case statusCheckedIn:
        return 'Checked In';
      case statusInProgress:
        return 'In progress';
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

  // Helper getter for clientId
  int get clientId => client.id;

  // Helper method to get status color
  Color get statusColor {
    switch (status) {
      case statusPending:
        return const Color.fromARGB(218, 94, 71, 38);
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
    int? salesRepId,
    int? status,
    String? notes,
    DateTime? checkInTime,
    double? latitude,
    double? longitude,
    String? imageUrl,
    Client? client,
    DateTime? checkoutTime,
    double? checkoutLatitude,
    double? checkoutLongitude,
  }) {
    return JourneyPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      salesRepId: salesRepId ?? this.salesRepId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      checkInTime: checkInTime ?? this.checkInTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      client: client ?? this.client,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      checkoutLatitude: checkoutLatitude ?? this.checkoutLatitude,
      checkoutLongitude: checkoutLongitude ?? this.checkoutLongitude,
    );
  }

  factory JourneyPlan.fromJson(Map<String, dynamic> json) {
    if (json['date'] == null) {
      throw FormatException('Journey date is required');
    }
    if (json['client'] == null) {
      throw FormatException('Client information is required');
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
      salesRepId: json['salesRepId'],
      status: status,
      notes: json['notes'],
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
      client: Client.fromJson(json['client']),
      checkoutTime:
          json['checkoutTime'] != null ? parseDate(json['checkoutTime']) : null,
      checkoutLatitude: json['checkoutLatitude'] != null
          ? (json['checkoutLatitude'] is double
              ? json['checkoutLatitude']
              : double.tryParse(json['checkoutLatitude'].toString()))
          : null,
      checkoutLongitude: json['checkoutLongitude'] != null
          ? (json['checkoutLongitude'] is double
              ? json['checkoutLongitude']
              : double.tryParse(json['checkoutLongitude'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time,
      'salesRepId': salesRepId,
      'status': status,
      'notes': notes,
      'checkInTime': checkInTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'client': client.toJson(),
      'checkoutTime': checkoutTime?.toIso8601String(),
      'checkoutLatitude': checkoutLatitude,
      'checkoutLongitude': checkoutLongitude,
    };
  }
}
