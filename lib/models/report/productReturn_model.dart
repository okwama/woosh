class ProductReturn {
  final int reportId;
  final String? productName;
  final String? reason;
  final String? imageUrl;
  final int? quantity;

  ProductReturn({
    required this.reportId,
    this.productName,
    this.reason,
    this.imageUrl,
    this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'productName': productName,
      'reason': reason,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory ProductReturn.fromJson(Map<String, dynamic> json) {
    return ProductReturn(
      reportId: json['reportId'] ?? 0,
      productName: json['productName'],
      reason: json['reason'],
      imageUrl: json['imageUrl'],
      quantity: json['quantity'],
    );
  }
}
