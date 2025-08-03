import 'product_model.dart';

/// Represents an item within an order, linking a product to its ordered quantity.
/// Handles cases where the product might be deleted after order creation.
class OrderItem {
  final int? id;
  final int salesOrderId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double taxAmount;
  final double totalPrice;
  final String? taxType;
  final double netPrice;
  final int? shippedQuantity;
  final Product? product;

  OrderItem({
    this.id,
    required this.salesOrderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.taxAmount,
    required this.totalPrice,
    this.taxType,
    required this.netPrice,
    this.shippedQuantity,
    this.product,
  })  : assert(quantity > 0, 'Quantity must be positive'),
        assert(product == null || product.id == productId,
            'Product ID mismatch between item and product object');

  /// Parses JSON into an OrderItem with proper null checks
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      return OrderItem(
        id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
        salesOrderId: json['salesOrderId'] ?? json['sales_order_id'] ?? 0,
        productId: json['productId'] != null || json['product_id'] != null
            ? int.tryParse((json['productId'] ?? json['product_id']).toString()) ?? 0
            : 0,
        quantity: json['quantity'] != null
            ? int.tryParse(json['quantity'].toString()) ?? 0
            : 0,
        unitPrice: json['unitPrice'] != null || json['unit_price'] != null
            ? double.tryParse((json['unitPrice'] ?? json['unit_price']).toString()) ?? 0.0
            : 0.0,
        taxAmount: json['taxAmount'] != null || json['tax_amount'] != null
            ? double.tryParse((json['taxAmount'] ?? json['tax_amount']).toString()) ?? 0.0
            : 0.0,
        totalPrice: json['totalPrice'] != null || json['total_price'] != null
            ? double.tryParse((json['totalPrice'] ?? json['total_price']).toString()) ?? 0.0
            : 0.0,
        taxType: json['taxType'] ?? json['tax_type'],
        netPrice: json['netPrice'] != null || json['net_price'] != null
            ? double.tryParse((json['netPrice'] ?? json['net_price']).toString()) ?? 0.0
            : 0.0,
        shippedQuantity: json['shippedQuantity'] != null || json['shipped_quantity'] != null
            ? int.tryParse((json['shippedQuantity'] ?? json['shipped_quantity']).toString())
            : null,
        product: json['product'] != null || json['products'] != null
            ? Product.fromJson((json['product'] ?? json['products']) as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      throw FormatException('Failed to parse OrderItem: $e');
    }
  }

  /// Converts to JSON, automatically excluding null fields
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'sales_order_id': salesOrderId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_amount': taxAmount,
        'total_price': totalPrice,
        if (taxType != null) 'tax_type': taxType,
        'net_price': netPrice,
        if (shippedQuantity != null) 'shipped_quantity': shippedQuantity,
        if (product != null) 'products': product!.toJson(),
      };

  /// Creates a copy with modified fields
  OrderItem copyWith({
    int? id,
    int? salesOrderId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? taxAmount,
    double? totalPrice,
    String? taxType,
    double? netPrice,
    int? shippedQuantity,
    Product? product,
  }) =>
      OrderItem(
        id: id ?? this.id,
        salesOrderId: salesOrderId ?? this.salesOrderId,
        productId: productId ?? this.productId,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        taxAmount: taxAmount ?? this.taxAmount,
        totalPrice: totalPrice ?? this.totalPrice,
        taxType: taxType ?? this.taxType,
        netPrice: netPrice ?? this.netPrice,
        shippedQuantity: shippedQuantity ?? this.shippedQuantity,
        product: product ?? this.product,
      );

  /// Gets the effective product name (handles null product)
  String get productName => product?.productName ?? 'Unknown Product';

  /// Calculates item total price (returns stored total if available)
  double get calculatedTotalPrice => unitPrice * quantity;

  @override
  String toString() => 'OrderItem('
      'id: $id, '
      'salesOrderId: $salesOrderId, '
      'productId: $productId, '
      'quantity: $quantity, '
      'unitPrice: $unitPrice, '
      'totalPrice: $totalPrice, '
      'netPrice: $netPrice, '
      'product: ${product?.id ?? "null"})';
}
