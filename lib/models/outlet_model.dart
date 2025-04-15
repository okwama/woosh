class Outlet {
  final int id;
  final String name;
  final String? kraPin;
  final String? email;
  final String? phone;
  final String? balance;
  final String address;
  final double? latitude;
  final double? longitude;

  Outlet({
    required this.id,
    required this.name,
    this.kraPin,
    this.email,
    this.phone,
    this.balance,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'],
      name: json['name'],
      kraPin: json['kraPin'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      balance: json['balance'] ?? '',
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'email': email,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static Outlet defaultOutlet() {
    return Outlet(
      id: 0,
      name: 'Unknown',
      address: '',
      balance: '',
      kraPin: '',
      email: '',
      phone: '',
      latitude: 0.0,
      longitude: 0.0,
    );
  }
}
