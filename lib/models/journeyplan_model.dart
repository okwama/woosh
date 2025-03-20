import 'package:whoosh/models/outlet_model.dart';

class JourneyPlan {
  final int? id;
  final DateTime date;
  final String time;
  final int? userId;
  final String status; // "pending", "checked_in", "completed"
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

    return JourneyPlan(
      id: json['id'],
      date: date,
      time: time,
      userId: json['userId'],
      status: json['status'] ?? 'pending',
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
