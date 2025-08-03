import 'price_option_model.dart';
import 'store_quantity_model.dart';

class Product {
  final int id;
  final String productCode;
  final String productName;
  // ignore: non_constant_identifier_names
  final int category_id;
  final String? category;
  final String? description;
  final String? unitOfMeasure;
  final double? costPrice;
  final double? sellingPrice;
  final int? reorderLevel;
  final int? currentStock;
  final bool? isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final List<PriceOption> priceOptions;
  final List<StoreQuantity> storeInventory;

  Product({
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
    this.priceOptions = const [],
    this.storeInventory = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      print('[Product] Parsing JSON: $json');

      // Debug each field individually
      final id = json['id'] ?? 0;
      print('[Product] id: $id (${id.runtimeType})');

      final productCode = json['productCode'] ?? json['product_code'] ?? '';
      print('[Product] productCode: $productCode (${productCode.runtimeType})');

      final productName = json['productName'] ?? json['product_name'] ?? '';
      print('[Product] productName: $productName (${productName.runtimeType})');

      final categoryId = json['categoryId'] != null
          ? int.tryParse(json['categoryId'].toString()) ?? 0
          : json['category_id'] != null
              ? int.tryParse(json['category_id'].toString()) ?? 0
              : 0;
      print('[Product] categoryId: $categoryId (${categoryId.runtimeType})');

      final costPrice = json['costPrice'] != null
          ? double.tryParse(json['costPrice'].toString())
          : json['cost_price'] != null
              ? double.tryParse(json['cost_price'].toString())
              : null;
      print('[Product] costPrice: $costPrice (${costPrice.runtimeType})');

      final sellingPrice = json['sellingPrice'] != null
          ? double.tryParse(json['sellingPrice'].toString())
          : json['selling_price'] != null
              ? double.tryParse(json['selling_price'].toString())
              : null;
      print(
          '[Product] sellingPrice: $sellingPrice (${sellingPrice.runtimeType})');

      final currentStock = json['currentStock'] != null
          ? int.tryParse(json['currentStock'].toString())
          : json['current_stock'] != null
              ? int.tryParse(json['current_stock'].toString())
              : null;
      print(
          '[Product] currentStock: $currentStock (${currentStock.runtimeType})');

      final isActive = json['isActive'] != null
          ? (json['isActive'] is bool
              ? json['isActive']
              : json['isActive'].toString().toLowerCase() == 'true')
          : json['is_active'] != null
              ? (json['is_active'] is bool
                  ? json['is_active']
                  : json['is_active'].toString().toLowerCase() == 'true')
              : null;
      print('[Product] isActive: $isActive (${isActive.runtimeType})');

      return Product(
        id: json['id'] ?? 0,
        productCode: json['productCode'] ?? json['product_code'] ?? '',
        productName: json['productName'] ?? json['product_name'] ?? '',
        category_id: json['categoryId'] != null
            ? int.tryParse(json['categoryId'].toString()) ?? 0
            : json['category_id'] != null
                ? int.tryParse(json['category_id'].toString()) ?? 0
                : 0,
        category: json['category'],
        description: json['description'],
        unitOfMeasure: json['unit_of_measure'],
        costPrice: json['costPrice'] != null
            ? double.tryParse(json['costPrice'].toString())
            : json['cost_price'] != null
                ? double.tryParse(json['cost_price'].toString())
                : null,
        sellingPrice: json['sellingPrice'] != null
            ? double.tryParse(json['sellingPrice'].toString())
            : json['selling_price'] != null
                ? double.tryParse(json['selling_price'].toString())
                : null,
        reorderLevel: json['reorder_level'] != null
            ? int.tryParse(json['reorder_level'].toString())
            : null,
        currentStock: json['currentStock'] != null
            ? int.tryParse(json['currentStock'].toString())
            : json['current_stock'] != null
                ? int.tryParse(json['current_stock'].toString())
                : null,
        isActive: json['isActive'] != null
            ? (json['isActive'] is bool
                ? json['isActive']
                : json['isActive'].toString().toLowerCase() == 'true')
            : json['is_active'] != null
                ? (json['is_active'] is bool
                    ? json['is_active']
                    : json['is_active'].toString().toLowerCase() == 'true')
                : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        imageUrl: json['imageUrl'] ?? json['image_url'],
        priceOptions: (json['priceOptions'] as List<dynamic>?)
                ?.map((e) => PriceOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            (json['categoryEntity'] != null && json['categoryEntity']['categoryPriceOptions'] != null
                ? (json['categoryEntity']['categoryPriceOptions'] as List<dynamic>)
                    .map((e) => PriceOption.fromJson(e as Map<String, dynamic>))
                    .toList()
                : []) ??
            [],
        storeInventory: (json['storeInventory'] as List<dynamic>?)
                ?.map((e) => StoreQuantity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            (json['store_inventory'] as List<dynamic>?)
                ?.map((e) => StoreQuantity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e, stackTrace) {
      print('[Product] Error parsing JSON: $e');
      print('[Product] Stack trace: $stackTrace');
      print('[Product] Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_code': productCode,
      'product_name': productName,
      'category_id': category_id,
      'category': category,
      'description': description,
      'unit_of_measure': unitOfMeasure,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'reorder_level': reorderLevel,
      'current_stock': currentStock,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_url': imageUrl,
      'priceOptions': priceOptions.map((e) => e.toJson()).toList(),
      'store_inventory': storeInventory.map((e) => e.toJson()).toList(),
    };
  }

  // Helper method to get quantity for a specific store
  int getQuantityForStore(int storeId) {
    final storeQuantity = storeInventory.firstWhere(
      (sq) => sq.storeId == storeId,
      orElse: () =>
          StoreQuantity(id: 0, storeId: storeId, productId: id, quantity: 0),
    );
    return storeQuantity.quantity;
  }

  // Helper method to get maximum quantity available in a region
  int getMaxQuantityInRegion(int regionId) {
    // Early return if no store quantities
    if (storeInventory.isEmpty) {
      return 0;
    }

    int maxQuantity = 0;

    // Single pass through store quantities
    for (final sq in storeInventory) {
      final store = sq.store;
      if (store != null &&
          (store.regionId == regionId || store.regionId == null)) {
        if (sq.quantity > maxQuantity) {
          maxQuantity = sq.quantity;
        }
      }
    }

    return maxQuantity;
  }

  // Helper method to get maximum quantity available in a country
  int getMaxQuantityInCountry(int countryId) {
    // Early return if no store quantities
    if (storeInventory.isEmpty) {
      return 0;
    }

    int maxQuantity = 0;

    // Single pass through store quantities
    for (final sq in storeInventory) {
      final store = sq.store;
      if (store != null && store.countryId == countryId) {
        if (sq.quantity > maxQuantity) {
          maxQuantity = sq.quantity;
        }
      }
    }

    return maxQuantity;
  }

  // Helper method to get total quantity across all stores
  int getTotalQuantity() {
    if (storeInventory.isEmpty) {
      return 0;
    }

    int totalQuantity = 0;
    for (final sq in storeInventory) {
      totalQuantity += sq.quantity;
    }

    return totalQuantity;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  static Product defaultProduct() {
    return Product(
      id: 0,
      productCode: '',
      productName: 'Unknown',
      category_id: 0,
      category: 'Unknown',
      description: '',
      unitOfMeasure: 'PCS',
      costPrice: 0.0,
      sellingPrice: 0.0,
      reorderLevel: 0,
      currentStock: 0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: '',
      priceOptions: [],
      storeInventory: [],
    );
  }
}
