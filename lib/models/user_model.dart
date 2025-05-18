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
  final int? routeId;
  final String? route;
  final String? country;
  final int? countryId;
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
    this.routeId,
    this.route,
    this.country,
    this.countryId,
    this.status,
    this.photoUrl,
    //this.department,
  });

  factory SalesRep.fromJson(Map<String, dynamic> json) {
    return SalesRep(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      role: json['role'],
      region: json['region'],
      regionId: json['region_id'],
      routeId: json['route_id'],
      route: json['route'],
      country: json['country'],
      countryId: json['countryId'],
      status: json['status'],
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'region': region,
      'region_id': regionId,
      'route_id': routeId,
      'route': route,
      'country': country,
      'countryId': countryId,
      'status': status,
      'photoUrl': photoUrl,
      //'department': department,
    };
  }
}
