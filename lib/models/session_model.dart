class Session {
  final int id;
  final int userId;
  final DateTime loginAt;
  final DateTime? logoutAt;
  final String timezone;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final bool isLate;
  final bool? isEarly;
  final String? duration;
  final String status;

  Session({
    required this.id,
    required this.userId,
    required this.loginAt,
    this.logoutAt,
    required this.timezone,
    required this.shiftStart,
    required this.shiftEnd,
    required this.isLate,
    this.isEarly,
    this.duration,
    required this.status,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      userId: json['userId'],
      loginAt: DateTime.parse(json['loginAt']),
      logoutAt:
          json['logoutAt'] != null ? DateTime.parse(json['logoutAt']) : null,
      timezone: json['timezone'],
      shiftStart: DateTime.parse(json['shiftStart']),
      shiftEnd: DateTime.parse(json['shiftEnd']),
      isLate: json['isLate'],
      isEarly: json['isEarly'],
      duration: json['duration']?.toString(),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'loginAt': loginAt.toIso8601String(),
      'logoutAt': logoutAt?.toIso8601String(),
      'timezone': timezone,
      'shiftStart': shiftStart.toIso8601String(),
      'shiftEnd': shiftEnd.toIso8601String(),
      'isLate': isLate,
      'isEarly': isEarly,
      'duration': duration,
      'status': status,
    };
  }

  String get formattedDuration {
    if (duration == null) return 'N/A';
    return duration!;
  }

  String get formattedStatus {
    switch (status) {
      case '1':
        return 'Early';
      case '2':
        return 'Overtime';
      default:
        return isLate ? 'Late' : 'On Time';
    }
  }
}
