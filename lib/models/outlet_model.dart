class Outlet {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
