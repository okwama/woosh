import 'package:whoosh/models/outlet_model.dart';

class JourneyPlan {
  final int? id;
  final DateTime date;
  final DateTime time;
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
  print('Parsing journey plan: $json');

  return JourneyPlan(
    id: json['id'],
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(), // Default to current date if null
    time: json['time'] != null ? DateTime.parse(json['time'] as String) : DateTime.now(), // Default to current time if null
    userId: json['userId'],
    status: json['status'] ?? 'pending', // Default to 'pending' if null
    checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime'] as String) : null,
    latitude: json['latitude'] != null ? (json['latitude'] is double ? json['latitude'] : json['latitude'].toDouble()) : null,
    longitude: json['longitude'] != null ? (json['longitude'] is double ? json['longitude'] : json['longitude'].toDouble()) : null,
    imageUrl: json['imageUrl'],
    outlet: Outlet.fromJson(json['outlet']), // Ensure Outlet.fromJson handles null values
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time.toIso8601String(),
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
