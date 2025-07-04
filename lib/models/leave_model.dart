import 'package:woosh/models/user_model.dart';

enum LeaveStatus { PENDING, APPROVED, DECLINED }

class Leave {
  final int? id;
  final int userId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? attachment;
  final LeaveStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SalesRep? user; // For admin view

  Leave({
    this.id,
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.attachment,
    this.status = LeaveStatus.PENDING,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json['id'],
      userId: json['userId'],
      leaveType: json['leaveType'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      reason: json['reason'],
      attachment: json['attachment'],
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      user: json['user'] != null ? SalesRep.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      if (attachment != null) 'attachment': attachment,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static LeaveStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return LeaveStatus.PENDING;
      case 'APPROVED':
        return LeaveStatus.APPROVED;
      case 'DECLINED':
        return LeaveStatus.DECLINED;
      default:
        return LeaveStatus.PENDING;
    }
  }

  // Get the duration of leave in days
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  // Check if leave dates overlap with another leave
  bool overlaps(Leave other) {
    return (startDate.isBefore(other.endDate) ||
            startDate.isAtSameMomentAs(other.endDate)) &&
        (endDate.isAfter(other.startDate) ||
            endDate.isAtSameMomentAs(other.startDate));
  }

  // Create a copy of the leave with some fields updated
  Leave copyWith({
    int? id,
    int? userId,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? attachment,
    LeaveStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    SalesRep? user,
  }) {
    return Leave(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      attachment: attachment ?? this.attachment,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'Leave{id: $id, leaveType: $leaveType, status: $status, startDate: $startDate, endDate: $endDate}';
  }
}
