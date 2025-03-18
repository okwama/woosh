class JourneyPlan {
  final int id;
  final DateTime date;
  final DateTime time;
  final int userId;
  final int outletId;

  JourneyPlan({
    required this.id,
    required this.date,
    required this.time,
    required this.userId,
    required this.outletId,
  });

  factory JourneyPlan.fromJson(Map<String, dynamic> json) {
    return JourneyPlan(
      id: json['id'],
      date: DateTime.parse(json['date']),
      time: DateTime.parse(json['time']),
      userId: json['userId'],
      outletId: json['outletId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time.toIso8601String(),
      'userId': userId,
      'outletId': outletId,
    };
  }
}