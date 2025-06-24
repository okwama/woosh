import 'package:hive/hive.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/models/store_quantity_model.dart';

// This part reference will be generated after running build_runner
part 'product_model.g.dart';

@HiveType(typeId: 12) // Using typeId 12 which is available
class ProductHiveModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int category_id;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String? imageUrl;

  @HiveField(6)
  final int? clientId;

  @HiveField(7)
  final int? packSize;

  @HiveField(8)
  final String createdAt;

  @HiveField(9)
  final String updatedAt;

  // We can't store complex objects like PriceOption in Hive directly
  // So we'll store the first price option values for simplicity
  @HiveField(10)
  final int? defaultPriceOptionId;

  @HiveField(11)
  final String? defaultPriceOption;

  @HiveField(12)
  final double? defaultPriceValue;

  @HiveField(13)
  final int? defaultPriceCategoryId;

  ProductHiveModel({
    required this.id,
    required this.name,
    required this.category_id,
    required this.category,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.clientId,
    this.packSize,
    this.defaultPriceOptionId,
    this.defaultPriceOption,
    this.defaultPriceValue,
    this.defaultPriceCategoryId,
  });

  // Convert from API Product model to Hive model
  factory ProductHiveModel.fromProduct(Product product) {
    // Get the default price option details if available
    int? defaultPriceOptionId;
    String? defaultPriceOption;
    double? defaultPriceValue;
    int? defaultPriceCategoryId;

    if (product.priceOptions.isNotEmpty) {
      final firstOption = product.priceOptions.first;
      defaultPriceOptionId = firstOption.id;
      defaultPriceOption = firstOption.option;
      defaultPriceValue = firstOption.value?.toDouble();
      defaultPriceCategoryId = firstOption.categoryId;
    }

    return ProductHiveModel(
      id: product.id,
      name: product.name,
      category_id: product.category_id,
      category: product.category,
      description: product.description,
      createdAt: product.createdAt.toIso8601String(),
      updatedAt: product.updatedAt.toIso8601String(),
      imageUrl: product.imageUrl,
      clientId: product.clientId,
      packSize: product.packSize,
      defaultPriceOptionId: defaultPriceOptionId,
      defaultPriceOption: defaultPriceOption,
      defaultPriceValue: defaultPriceValue,
      defaultPriceCategoryId: defaultPriceCategoryId,
    );
  }

  // Convert from Hive model to API Product model
  Product toProduct() {
    List<PriceOption> priceOptions = [];

    // Create a price option if we have default price values
    if (defaultPriceOptionId != null &&
        defaultPriceOption != null &&
        defaultPriceValue != null) {
      priceOptions.add(PriceOption(
        id: defaultPriceOptionId!,
        option: defaultPriceOption!,
        value: defaultPriceValue!.toInt(),
        value_tzs: null, // Nullable value
        value_ngn: null, // Nullable value
        categoryId: defaultPriceCategoryId ??
            category_id, // Use the stored category ID or fall back to product's category_id
      ));
    }

    return Product(
      id: id,
      name: name,
      category_id: category_id,
      category: category,
      description: description,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      imageUrl: imageUrl,
      clientId: clientId,
      packSize: packSize,
      priceOptions: priceOptions,
      storeQuantities: [],
    );
  }
}
