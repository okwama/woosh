class ProductReturnItem {
  final String? productName;
  final int? quantity;
  final String? reason;
  final String? imageUrl;

  ProductReturnItem({
    this.productName,
    this.quantity,
    this.reason,
    this.imageUrl,
  });

  factory ProductReturnItem.fromJson(Map<String, dynamic> json) {
    return ProductReturnItem(
      productName: json['productName'],
      quantity: json['quantity'],
      reason: json['reason'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'quantity': quantity,
        'reason': reason,
        'imageUrl': imageUrl,
      };
}