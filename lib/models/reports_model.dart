class Report {
  final int orderId;
  final String product;
  final int quantity;
  final int outletId;
  final String outletName;
  final String outletAddress;
  final DateTime createdAt;
  final double totalSalesValue;
  final int stockLevel;
  final int reorderLevel;
  final DateTime salesDate;
  final int userId;
  final String inventoryStatus;

  Report({
    required this.orderId,
    required this.product,
    required this.quantity,
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    required this.createdAt,
    required this.totalSalesValue,
    required this.stockLevel,
    required this.reorderLevel,
    required this.salesDate,
    required this.userId,
    required this.inventoryStatus,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      orderId: json['orderId'],
      product: json['product'],
      quantity: json['quantity'],
      outletId: json['outletId'],
      outletName: json['outletName'],
      outletAddress: json['outletAddress'],
      createdAt: DateTime.parse(json['createdAt']),
      totalSalesValue: json['totalSalesValue'],
      stockLevel: json['stockLevel'],
      reorderLevel: json['reorderLevel'],
      salesDate: DateTime.parse(json['salesDate']),
      userId: json['userId'],
      inventoryStatus: json['inventoryStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'product': product,
      'quantity': quantity,
      'outletId': outletId,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'createdAt': createdAt.toIso8601String(),
      'totalSalesValue': totalSalesValue,
      'stockLevel': stockLevel,
      'reorderLevel': reorderLevel,
      'salesDate': salesDate.toIso8601String(),
      'userId': userId,
      'inventoryStatus': inventoryStatus,
    };
  }
}
