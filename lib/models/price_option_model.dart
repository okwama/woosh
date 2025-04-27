class PriceOption {
  final int id;
  final String option;
  final int value;
  final int categoryId;

  PriceOption({
    required this.id,
    required this.option,
    required this.value,
    required this.categoryId,
  });

  factory PriceOption.fromJson(Map<String, dynamic> json) {
    return PriceOption(
      id: json['id'] as int,
      option: json['option'] as String,
      value: json['value'] as int,
      categoryId: json['categoryId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'option': option,
        'value': value,
        'categoryId': categoryId,
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
