class Client {
  final int id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? balance;
  final String? email;
  final int regionId;
  final String region;
  final int? routeId;
  final String? routeName;
  final int? routeIdUpdate;
  final String? routeNameUpdate;
  final String contact;
  final String? taxPin;
  final String? location;
  final int status;
  final int? clientType;
  final int? outletAccount;
  final int countryId;
  final int? addedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Client({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.balance,
    this.email,
    required this.regionId,
    required this.region,
    this.routeId,
    this.routeName,
    this.routeIdUpdate,
    this.routeNameUpdate,
    required this.contact,
    this.taxPin,
    this.location,
    this.status = 1,
    this.clientType,
    this.outletAccount,
    required this.countryId,
    this.addedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse numeric values
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          print('Error parsing double from string "$value": $e');
          return null;
        }
      }
      return null;
    }

    return Client(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      balance: parseDouble(json['balance']),
      email: json['email'],
      regionId: json['regionId'] ?? json['region_id'] ?? 0,
      region: json['region'] ?? '',
      routeId: json['routeId'] ?? json['route_id'],
      routeName: json['routeName'] ?? json['route_name'],
      routeIdUpdate: json['routeIdUpdate'] ?? json['route_id_update'],
      routeNameUpdate: json['routeNameUpdate'] ?? json['route_name_update'],
      contact: json['contact'] ?? '',
      taxPin: json['taxPin'] ?? json['tax_pin'],
      location: json['location'],
      status: json['status'] ?? 1,
      clientType: json['clientType'] ?? json['client_type'],
      outletAccount: json['outletAccount'] ?? json['outlet_account'],
      countryId: json['countryId'] ?? json['country_id'] ?? 0,
      addedBy: json['addedBy'] ?? json['added_by'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'balance': balance,
      'email': email,
      'regionId': regionId,
      'region': region,
      'routeId': routeId,
      'routeName': routeName,
      'routeIdUpdate': routeIdUpdate,
      'routeNameUpdate': routeNameUpdate,
      'contact': contact,
      'taxPin': taxPin,
      'location': location,
      'status': status,
      'clientType': clientType,
      'outletAccount': outletAccount,
      'countryId': countryId,
      'addedBy': addedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Client copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? balance,
    String? email,
    int? regionId,
    String? region,
    int? routeId,
    String? routeName,
    int? routeIdUpdate,
    String? routeNameUpdate,
    String? contact,
    String? taxPin,
    String? location,
    int? status,
    int? clientType,
    int? outletAccount,
    int? countryId,
    int? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      balance: balance ?? this.balance,
      email: email ?? this.email,
      regionId: regionId ?? this.regionId,
      region: region ?? this.region,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      routeIdUpdate: routeIdUpdate ?? this.routeIdUpdate,
      routeNameUpdate: routeNameUpdate ?? this.routeNameUpdate,
      contact: contact ?? this.contact,
      taxPin: taxPin ?? this.taxPin,
      location: location ?? this.location,
      status: status ?? this.status,
      clientType: clientType ?? this.clientType,
      outletAccount: outletAccount ?? this.outletAccount,
      countryId: countryId ?? this.countryId,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, region: $region, contact: $contact)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
