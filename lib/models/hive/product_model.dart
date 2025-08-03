import 'package:hive/hive.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/models/store_quantity_model.dart';

// This part reference will be generated after running build_runner
part 'product_model.g.dart';

@HiveType(typeId: 21)
class ProductHiveModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String productCode;

  @HiveField(2)
  final String productName;

  @HiveField(3)
  final int category_id;

  @HiveField(4)
  final String? category;

  @HiveField(5)
  final String? description;

  @HiveField(6)
  final String? unitOfMeasure;

  @HiveField(7)
  final double? costPrice;

  @HiveField(8)
  final double? sellingPrice;

  @HiveField(9)
  final int? reorderLevel;

  @HiveField(10)
  final int? currentStock;

  @HiveField(11)
  final bool? isActive;

  @HiveField(12)
  final String createdAt;

  @HiveField(13)
  final String updatedAt;

  @HiveField(14)
  final String? imageUrl;

  // Price option data
  @HiveField(15)
  final int? defaultPriceOptionId;

  @HiveField(16)
  final String? defaultPriceOptionLabel;

  @HiveField(17)
  final double? defaultPriceValue;

  @HiveField(18)
  final double? defaultPriceValueTzs;

  @HiveField(19)
  final double? defaultPriceValueNgn;

  @HiveField(20)
  final int? defaultPriceCategoryId;

  // Store inventory data
  @HiveField(21)
  final List<Map<String, dynamic>> storeInventoryData;

  ProductHiveModel({
    required this.id,
    required this.productCode,
    required this.productName,
    required this.category_id,
    this.category,
    this.description,
    this.unitOfMeasure,
    this.costPrice,
    this.sellingPrice,
    this.reorderLevel,
    this.currentStock,
    this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.defaultPriceOptionId,
    this.defaultPriceOptionLabel,
    this.defaultPriceValue,
    this.defaultPriceValueTzs,
    this.defaultPriceValueNgn,
    this.defaultPriceCategoryId,
    this.storeInventoryData = const [],
  });

  // Convert from API Product model to Hive model
  static ProductHiveModel fromProduct(Product product) {
    int? defaultPriceOptionId;
    String? defaultPriceOptionLabel;
    double? defaultPriceValue;
    double? defaultPriceValueTzs;
    double? defaultPriceValueNgn;
    int? defaultPriceCategoryId;

    if (product.priceOptions.isNotEmpty) {
      final firstOption = product.priceOptions.first;
      defaultPriceOptionId = firstOption.id;
      defaultPriceOptionLabel = firstOption.label;
      defaultPriceValue = firstOption.value;
      defaultPriceValueTzs = firstOption.valueTzs;
      defaultPriceValueNgn = firstOption.valueNgn;
      defaultPriceCategoryId = firstOption.categoryId;
    }

    // Convert store inventory to serializable format
    final storeInventoryData =
        product.storeInventory.map((si) => si.toJson()).toList();

    return ProductHiveModel(
      id: product.id,
      productCode: product.productCode,
      productName: product.productName,
      category_id: product.category_id,
      category: product.category,
      description: product.description,
      unitOfMeasure: product.unitOfMeasure,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      reorderLevel: product.reorderLevel,
      currentStock: product.currentStock,
      isActive: product.isActive,
      createdAt: product.createdAt.toIso8601String(),
      updatedAt: product.updatedAt.toIso8601String(),
      imageUrl: product.imageUrl,
      defaultPriceOptionId: defaultPriceOptionId,
      defaultPriceOptionLabel: defaultPriceOptionLabel,
      defaultPriceValue: defaultPriceValue,
      defaultPriceValueTzs: defaultPriceValueTzs,
      defaultPriceValueNgn: defaultPriceValueNgn,
      defaultPriceCategoryId: defaultPriceCategoryId,
      storeInventoryData: storeInventoryData,
    );
  }

  // Convert from Hive model to API Product model
  Product toProduct() {
    List<PriceOption> priceOptions = [];

    // Create a price option if we have default price values
    if (defaultPriceOptionId != null &&
        defaultPriceOptionLabel != null &&
        defaultPriceValue != null) {
      priceOptions.add(PriceOption(
        id: defaultPriceOptionId!,
        categoryId: defaultPriceCategoryId ?? category_id,
        label: defaultPriceOptionLabel!,
        value: defaultPriceValue,
        valueTzs: defaultPriceValueTzs,
        valueNgn: defaultPriceValueNgn,
      ));
    }

    return Product(
      id: id,
      productCode: productCode,
      productName: productName,
      category_id: category_id,
      category: category,
      description: description,
      unitOfMeasure: unitOfMeasure,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      reorderLevel: reorderLevel,
      currentStock: currentStock,
      isActive: isActive,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      imageUrl: imageUrl,
      priceOptions: priceOptions,
      storeInventory: storeInventoryData
          .map((data) => StoreQuantity.fromJson(data))
          .toList(),
    );
  }
}
