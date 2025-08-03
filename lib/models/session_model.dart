class Session {
  final int id;
  final int userId;
  final String? sessionStart;
  final String? sessionEnd;
  final String? duration;
  final String status;
  final String? timezone;
  final String? displayStatus;
  final String? statusLabel;

  Session({
    required this.id,
    required this.userId,
    required this.sessionStart,
    required this.sessionEnd,
    this.duration,
    required this.status,
    this.timezone,
    this.displayStatus,
    this.statusLabel,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      userId: json['userId'] != null
          ? int.tryParse(json['userId'].toString()) ?? 0
          : 0,
      sessionStart: json['sessionStart']?.toString(),
      sessionEnd: json['sessionEnd']?.toString(),
      duration: json['duration']?.toString(),
      status: json['status']?.toString() ?? '0',
      timezone: json['timezone']?.toString(),
      displayStatus: json['displayStatus']?.toString(),
      statusLabel: json['statusLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sessionStart': sessionStart,
      'sessionEnd': sessionEnd,
      'duration': duration,
      'status': status,
      'timezone': timezone,
      'displayStatus': displayStatus,
      'statusLabel': statusLabel,
    };
  }

  String get formattedDuration {
    if (duration == null) return 'N/A';

    // Handle negative durations (like "-2h 36m")
    if (duration!.startsWith('-')) {
      return duration!;
    }

    // Format raw minutes if needed (assuming duration might come as raw number)
    try {
      final minutes = int.tryParse(duration!);
      if (minutes != null) {
        final hours = (minutes / 60).floor();
        final mins = minutes % 60;
        return '${hours}h ${mins}m';
      }
    } catch (_) {}

    // If duration is already in a string format, try to parse it
    try {
      // Handle formats like "8h 30m" or "8:30"
      final parts = duration!.toLowerCase().split(RegExp(r'[h\s:]'));
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return '${hours}h ${minutes}m';
      }
    } catch (_) {}

    return duration!;
  }

  String get formattedStatus {
    switch (status) {
      case '1':
        return 'Active';
      case '2':
        return 'Ended';
      default:
        return displayStatus ?? 'Unknown';
    }
  }

  // Helper to get local login time
  String get displayLoginTime {
    return sessionStart ?? 'N/A';
  }

  // Helper to get local logout time
  String? get displayLogoutTime {
    return sessionEnd;
  }
}
