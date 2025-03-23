class ProductReport {
  final int reportId;
  final String? productName;
  final int? quantity;
  final String? comment;
  final DateTime createdAt;

  ProductReport({
    required this.reportId,
    this.productName,
    this.quantity,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'productName': productName,
      'quantity': quantity,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductReport.fromJson(Map<String, dynamic> json) {
    return ProductReport(
      reportId: json['reportId'],
      productName: json['productName'],
      quantity: json['quantity'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
