import 'package:whoosh/models/outlet_model.dart';

class JourneyPlan {
  final int id;
  final DateTime date;
  final DateTime time;
  final int userId;
  final int outletId;
  final Outlet outlet;

  JourneyPlan({
    required this.id,
    required this.date,
    required this.time,
    required this.userId,
    required this.outletId,
    required this.outlet,
  });

factory JourneyPlan.fromJson(Map<String, dynamic> json) {
  return JourneyPlan(
    id: json['id'],
    date: DateTime.parse(json['date']),
    time: DateTime.parse(json['time']),
    userId: json['userId'],
    outletId: json['outletId'],
    outlet: json['outlet'] != null 
        ? Outlet.fromJson(json['outlet']) 
        : Outlet(id: json['outletId'], name: 'Unknown', address: 'Unknown'),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time.toIso8601String(),
      'userId': userId,
      'outletId': outletId,
      'outlet': outlet.toJson(),
    };
  }
}