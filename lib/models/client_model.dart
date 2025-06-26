import 'package:woosh/models/outlet_model.dart';

class Client extends Outlet {
  Client({
    required super.id,
    required super.name,
    required super.address,
    super.latitude,
    super.longitude,
    super.balance,
    super.email,
    super.contact,
    super.taxPin,
    super.location,
    super.clientType,
    required int regionId,
    required String region,
    required int countryId,
  }) : super(
          regionId: regionId,
          region: region,
          countryId: countryId,
        );

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      balance: json['balance']?.toString(),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      email: json['email'] as String?,
      contact: json['contact'] as String?,
      taxPin: json['tax_pin'] as String?,
      location: json['location'] as String?,
      clientType: json['client_type'] as int?,
      regionId: json['region_id'] as int,
      region: json['region'] as String,
      countryId: json['countryId'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      if (balance != null) 'balance': balance,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (email != null) 'email': email,
      if (contact != null) 'contact': contact,
      if (taxPin != null) 'tax_pin': taxPin,
      if (location != null) 'location': location,
      if (clientType != null) 'client_type': clientType,
      'region_id': regionId,
      'region': region,
      'countryId': countryId,
    };
  }
}
