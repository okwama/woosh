import 'package:hive/hive.dart';
import 'package:glamour_queen/models/product_model.dart';
import 'package:glamour_queen/models/price_option_model.dart';
import 'package:glamour_queen/models/orderitem_model.dart';
import 'package:get/get.dart'; // For firstWhereOrNull

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
  final int? priceOptionId;

  @HiveField(4)
  final double unitPrice;

  @HiveField(5)
  final String? imageUrl;

  @HiveField(6)
  final int? packSize;

  CartItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.priceOptionId,
    required this.unitPrice,
    this.imageUrl,
    this.packSize,
  });

  factory CartItemModel.fromOrderItem(OrderItem item) {
    // Handle null price option ID for fallback pricing
    int? priceOptionId = item.priceOptionId;
    double unitPrice = 0.0;

    // If no price option ID is set, try to get the first available price option
    if (priceOptionId == null &&
        item.product?.priceOptions.isNotEmpty == true) {
      final firstOption = item.product!.priceOptions.first;
      priceOptionId = firstOption.id;
      unitPrice = firstOption.value;
    } else if (priceOptionId != null) {
      // Get the price from the selected price option
      unitPrice = (item.product?.priceOptions
              .firstWhereOrNull((po) => po.id == priceOptionId)
              ?.value ??
          0.0) as double;
    }

    // For fallback pricing, keep priceOptionId as null and set unitPrice to 0
    // The API will handle the actual pricing calculation

    return CartItemModel(
      productId: item.productId,
      productName: item.product?.name ?? 'Unknown Product',
      quantity: item.quantity,
      priceOptionId: priceOptionId, // Can be null for fallback pricing
      unitPrice: unitPrice,
      imageUrl: item.product?.imageUrl,
      packSize: item.product?.packSize,
    );
  }

  OrderItem toOrderItem() {
    return OrderItem(
      productId: productId,
      quantity: quantity,
      priceOptionId: priceOptionId,
      product: Product(
        id: productId,
        name: productName,
        imageUrl: imageUrl,
        packSize: packSize,
        category_id: 0, // Default value
        category: '', // Empty string instead of null
        createdAt: DateTime.now(), // Default value
        updatedAt: DateTime.now(), // Default value
        priceOptions: [
          PriceOption(
            id: priceOptionId ?? 0,
            value: unitPrice, // Use double directly
            option: 'Default', // Default value
            categoryId: 0, // Default value
          ),
        ],
      ),
    );
  }
}
