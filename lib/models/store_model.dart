class Store {
  final int id;
  final String name;
  final int? regionId;
  final int? countryId;
  final Region? region;

  Store({
    required this.id,
    required this.name,
    this.regionId,
    this.countryId,
    this.region,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    try {
      print('[Store] Parsing JSON: $json');
      return Store(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        regionId: json['regionId'] ?? json['region_id'],
        countryId: json['countryId'] ?? json['country_id'],
        region: json['region'] != null ? Region.fromJson(json['region']) : null,
      );
    } catch (e, stackTrace) {
      print('[Store] Error parsing JSON: $e');
      print('[Store] Stack trace: $stackTrace');
      print('[Store] Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'regionId': regionId,
      'countryId': countryId,
      if (region != null) 'region': region!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          regionId == other.regionId &&
          countryId == other.countryId &&
          region == other.region;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      (regionId?.hashCode ?? 0) ^
      (countryId?.hashCode ?? 0) ^
      (region?.hashCode ?? 0);
}

class Region {
  final int id;
  final String name;
  final Country? country;

  Region({
    required this.id,
    required this.name,
    this.country,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      country:
          json['country'] != null ? Country.fromJson(json['country']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (country != null) 'country': country!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          country == other.country;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ (country?.hashCode ?? 0);
}

class Country {
  final int id;
  final String name;

  Country({
    required this.id,
    required this.name,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
