class PriceOption {
  final int? id;
  final String option;
  final double value;
  final int categoryId;
  final double? originalValue;
  final double? discountPercentage;
  final bool? isFallback;

  PriceOption({
    this.id,
    required this.option,
    required this.value,
    required this.categoryId,
    this.originalValue,
    this.discountPercentage,
    this.isFallback,
  });

  factory PriceOption.fromJson(Map<String, dynamic> json) {
    return PriceOption(
      id: json['id'] as int?,
      option: json['option'] as String,
      value: (json['value'] as num).toDouble(),
      categoryId: json['categoryId'] as int? ?? 0,
      originalValue: json['originalValue'] != null
          ? (json['originalValue'] as num).toDouble()
          : null,
      discountPercentage: json['discountPercentage'] != null
          ? (json['discountPercentage'] as num).toDouble()
          : null,
      isFallback: json['isFallback'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'option': option,
        'value': value,
        'categoryId': categoryId,
        if (originalValue != null) 'originalValue': originalValue,
        if (discountPercentage != null)
          'discountPercentage': discountPercentage,
        if (isFallback != null) 'isFallback': isFallback,
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
