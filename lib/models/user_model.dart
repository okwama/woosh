import 'package:woosh/models/journeyPlan_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/token_model.dart';

class SalesRep {
  final int id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? role;
  final String? region;
  final int? regionId;
  final int? status;
  final String? photoUrl;
  //final String? department;

  SalesRep({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.role,
    this.region,
    this.regionId,
    this.status,
    this.photoUrl,
    //this.department,
  });

  factory SalesRep.fromJson(Map<String, dynamic> json) {
    // Support minimal user data from order responses
    if (json['name'] != null && json['id'] != null) {
      return SalesRep(
        id: json['id'],
        name: json['name'],
        email: json['email'] ?? '',
        phoneNumber: json['phoneNumber'] ?? '',
        role: json['role'],
        region: json['region'],
        regionId: json['regionId'],
        status: json['status'],
        photoUrl: json['photoUrl'],
      );
    }

    // Full user data parsing
    return SalesRep(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      role: json['role'],
      region: json['region'],
      regionId: json['regionId'],
      status: json['status'],
      photoUrl: json['photoUrl'],
      //department: json['department'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'role': role,
      'region': region,
      'regionId': regionId,
      'status': status,
      'photoUrl': photoUrl,
      //'department': department,
    };
  }
}
