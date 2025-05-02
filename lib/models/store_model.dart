class Store {
  final int id;
  final String name;
  final int? regionId;

  Store({
    required this.id,
    required this.name,
    this.regionId,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    try {
      print('[Store] Parsing JSON: $json');
      return Store(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        regionId: json['regionId'] ?? json['region_id'],
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
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          regionId == other.regionId;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ (regionId?.hashCode ?? 0);
}
