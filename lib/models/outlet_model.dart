
class Outlet {
  final int id;
  final String name;
  final String address;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    
  });

// In outlet_model.dart
factory Outlet.fromJson(Map<String, dynamic> json) {
  return Outlet(
    id: json['id'],
    name: json['name'],
    address: json['address'],
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
    };
  }
}