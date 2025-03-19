
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
    name: json['name'] ?? 'Unknown Outlet', // Default to 'Unknown Outlet' if null
    address: json['address'] ?? 'Unknown Address', // Default to 'Unknown Address' if null
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