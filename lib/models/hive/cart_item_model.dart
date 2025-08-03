import 'package:hive/hive.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/price_option_model.dart';

part 'cart_item_model.g.dart';

@HiveType(typeId: 20) // Updated to use the Order-related models range
class CartItemModel extends HiveObject {
  @HiveField(0)
  final int productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final double unitPrice;

  @HiveField(4)
  final double taxAmount;

  @HiveField(5)
  final double totalPrice;

  @HiveField(6)
  final double netPrice;

  @HiveField(7)
  final String? imageUrl;

  CartItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxAmount,
    required this.totalPrice,
    required this.netPrice,
    this.imageUrl,
  });

  factory CartItemModel.fromOrderItem(OrderItem item) {
    return CartItemModel(
      productId: item.productId,
      productName: item.product?.productName ?? 'Unknown Product',
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxAmount: item.taxAmount,
      totalPrice: item.totalPrice,
      netPrice: item.netPrice,
      imageUrl: item.product?.imageUrl,
    );
  }

  OrderItem toOrderItem() {
    return OrderItem(
      salesOrderId: 0, // Will be set when order is created
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      taxAmount: taxAmount,
      totalPrice: totalPrice,
      netPrice: netPrice,
      product: Product(
        id: productId,
        productCode: '',
        productName: productName,
        category_id: 0, // Default value
        category: '', // Empty string instead of null
        createdAt: DateTime.now(), // Default value
        updatedAt: DateTime.now(), // Default value
        imageUrl: imageUrl,
        priceOptions: [
          PriceOption(
            id: 0,
            categoryId: 0,
            label: 'Default',
            value: unitPrice,
            valueTzs: null,
            valueNgn: null,
          ),
        ],
        storeInventory: [],
      ),
    );
  }
}
