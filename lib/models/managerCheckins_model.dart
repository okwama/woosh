
import 'package:woosh/models/office_model.dart';

class ManagerCheckin {
  final int id;
  final int managerId;
  final int officeId;
  final DateTime date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final Office? office;

  ManagerCheckin({
    required this.id,
    required this.managerId,
    required this.officeId,
    required this.date,
    this.checkInAt,
    this.checkOutAt,
    this.latitude,
    this.longitude,
    this.notes,
    this.office,
  });

  factory ManagerCheckin.fromJson(Map<String, dynamic> json) {
    return ManagerCheckin(
      id: json['id'],
      managerId: json['managerId'],
      officeId: json['officeId'],
      date: DateTime.parse(json['date']),
      checkInAt:
          json['checkInAt'] != null ? DateTime.parse(json['checkInAt']) : null,
      checkOutAt: json['checkOutAt'] != null
          ? DateTime.parse(json['checkOutAt'])
          : null,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      notes: json['notes'],
      office: json['office'] != null ? Office.fromJson(json['office']) : null,
    );
  }
}
