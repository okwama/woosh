class Store {
  final int id;
  final String name;
  final int regionId;

  Store({
    required this.id,
    required this.name,
    required this.regionId,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      regionId: json['regionId'],
    );
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
  int get hashCode => id.hashCode ^ name.hashCode ^ regionId.hashCode;
}
