class PriceOption {
  final int? id;
  final String option;
  final int? value;
  final double? value_tzs;
  final double? value_ngn;
  final int categoryId;
  final double? originalValue;
  final double? discountPercentage;
  final bool? isFallback;

  PriceOption({
    this.id,
    required this.option,
    this.value,
    this.value_tzs,
    this.value_ngn,
    required this.categoryId,
    this.originalValue,
    this.discountPercentage,
    this.isFallback,
  });

  factory PriceOption.fromJson(Map<String, dynamic> json) {
    return PriceOption(
      id: json['id'] as int?,
      option: json['option'] as String,
      value: _parseValue(json['value']),
      value_tzs: _parseDoubleValue(json['value_tzs']),
      value_ngn: _parseDoubleValue(json['value_ngn']),
      categoryId: json['categoryId'] as int,
    );
  }

  // Helper method to parse value field which can be string or int
  static int? _parseValue(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }

    return null;
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
        'option': option,
        'value': value,
        'categoryId': categoryId,
        'value_tzs': value_tzs,
        'value_ngn': value_ngn,
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
