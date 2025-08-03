class PriceOption {
  final int? id;
  final int categoryId;
  final String label;
  final double? value;
  final double? valueTzs;
  final double? valueNgn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PriceOption({
    this.id,
    required this.categoryId,
    required this.label,
    this.value,
    this.valueTzs,
    this.valueNgn,
    this.createdAt,
    this.updatedAt,
  });

  factory PriceOption.fromJson(Map<String, dynamic> json) {
    return PriceOption(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      categoryId: json['categoryId'] != null
          ? int.tryParse(json['categoryId'].toString()) ?? 0
          : json['category_id'] != null
              ? int.tryParse(json['category_id'].toString()) ?? 0
              : 0,
      label: json['label']?.toString() ?? '',
      value: _parseDoubleValue(json['value']),
      valueTzs: _parseDoubleValue(json['valueTzs'] ?? json['value_tzs']),
      valueNgn: _parseDoubleValue(json['valueNgn'] ?? json['value_ngn']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  // Helper method to parse double value fields which can be string or num
  static double? _parseDoubleValue(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'label': label,
        'value': value,
        'value_tzs': valueTzs,
        'value_ngn': valueNgn,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
