import 'package:woosh/models/clients/client_model.dart';

class Outlet {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? email;
  final String? contact;
  final int regionId;
  final String region;
  final int countryId;
  final String? balance;
  final String? taxPin;
  final String? location;
  final int status;
  final int? clientType;
  final int? outletAccount;
  final int? addedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Outlet({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.email,
    this.contact,
    required this.regionId,
    required this.region,
    required this.countryId,
    this.balance,
    this.taxPin,
    this.location,
    required this.status,
    this.clientType,
    this.outletAccount,
    this.addedBy,
    this.createdAt,
    this.updatedAt,
  });

  // Convert from Client model
  factory Outlet.fromClient(Client client) {
    return Outlet(
      id: client.id,
      name: client.name,
      address: client.address ?? '',
      latitude: client.latitude,
      longitude: client.longitude,
      email: client.email,
      contact: client.contact,
      regionId: client.regionId,
      region: client.region,
      countryId: client.countryId,
      balance: client.balance?.toString(),
      taxPin: client.taxPin,
      location: client.location,
      status: client.status,
      clientType: client.clientType,
      outletAccount: client.outletAccount,
      addedBy: client.addedBy,
      createdAt: client.createdAt,
      updatedAt: client.updatedAt,
    );
  }

  // Convert from JSON
  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      email: json['email'],
      contact: json['contact'],
      regionId: json['region_id'] ?? json['regionId'] ?? 0,
      region: json['region'] ?? '',
      countryId: json['country_id'] ?? json['countryId'] ?? 0,
      balance: json['balance']?.toString(),
      taxPin: json['tax_pin'] ?? json['taxPin'],
      location: json['location'],
      status: json['status'] ?? 1,
      clientType: json['client_type'] ?? json['clientType'],
      outletAccount: json['outlet_account'] ?? json['outletAccount'],
      addedBy: json['added_by'] ?? json['addedBy'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // Convert to Client model
  Client toClient() {
    return Client(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      balance: balance != null ? double.tryParse(balance!) : null,
      email: email,
      regionId: regionId,
      region: region,
      contact: contact ?? '',
      taxPin: taxPin,
      location: location,
      status: status,
      clientType: clientType,
      outletAccount: outletAccount,
      countryId: countryId,
      addedBy: addedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
