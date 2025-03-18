import 'package:whoosh/models/journeyPlan_model.dart';

class Outlet {
  final int id;
  final String name;
  final String address;
  final List<JourneyPlan> journeyPlans;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    required this.journeyPlans,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      journeyPlans: (json['journeyPlans'] as List)
          .map((journeyPlan) => JourneyPlan.fromJson(journeyPlan))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'journeyPlans': journeyPlans.map((journeyPlan) => journeyPlan.toJson()).toList(),
    };
  }
}