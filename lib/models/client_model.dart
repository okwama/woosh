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
    // Debug logging
    print('Client.fromJson - Raw JSON: $json');

    // Safe parsing helper functions
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          print('Client.parseDouble error for value "$value": $e');
          return null;
        }
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        try {
          // Handle decimal strings by converting to double first, then to int
          if (value.contains('.')) {
            final doubleValue = double.tryParse(value);
            return doubleValue?.toInt();
          }
          return int.parse(value);
        } catch (e) {
          print('Client.parseInt error for value "$value": $e');
          return null;
        }
      }
      return null;
    }

    // Debug logging for each field
    final id = parseInt(json['id']) ?? 0;
    final latitude = parseDouble(json['latitude']);
    final longitude = parseDouble(json['longitude']);
    final clientType = parseInt(json['client_type']);
    final regionId = parseInt(json['region_id']) ?? 0;
    final countryId = parseInt(json['countryId']) ?? 0;

    print('Client parsing - id: ${json['id']} -> $id');
    print('Client parsing - latitude: ${json['latitude']} -> $latitude');
    print('Client parsing - longitude: ${json['longitude']} -> $longitude');
    print(
        'Client parsing - client_type: ${json['client_type']} -> $clientType');
    print('Client parsing - region_id: ${json['region_id']} -> $regionId');
    print('Client parsing - countryId: ${json['countryId']} -> $countryId');

    return Client(
      id: id,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      balance: json['balance']?.toString(),
      latitude: latitude,
      longitude: longitude,
      email: json['email']?.toString(),
      contact: json['contact']?.toString(),
      taxPin: json['tax_pin']?.toString(),
      location: json['location']?.toString(),
      clientType: clientType,
      regionId: regionId,
      region: json['region']?.toString() ?? '',
      countryId: countryId,
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
