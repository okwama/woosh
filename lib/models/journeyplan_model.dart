import 'package:whoosh/models/outlet_model.dart';

class JourneyPlan {
  // Status constants
  static const int STATUS_PENDING = 0;
  static const int STATUS_CHECKED_IN = 1;

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
  String get statusText =>
      status == STATUS_CHECKED_IN ? 'Checked In' : 'Pending';
  bool get isCheckedIn => status == STATUS_CHECKED_IN;
  bool get isPending => status == STATUS_PENDING;

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
            : int.tryParse(json['status'].toString()) ?? STATUS_PENDING)
        : STATUS_PENDING;

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
