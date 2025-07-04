import 'price_option_model.dart';
import 'store_quantity_model.dart';

class Product {
  final int id;
  final String name;
  // ignore: non_constant_identifier_names
  final int category_id;
  final String category;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final int? clientId;
  final List<PriceOption> priceOptions;
  final List<StoreQuantity> storeQuantities;
  final int? packSize;

  Product({
    required this.id,
    required this.name,
    required this.category_id,
    required this.category,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.clientId,
    this.priceOptions = const [],
    this.storeQuantities = const [],
    this.packSize,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      print('[Product] Parsing JSON: $json');
      return Product(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        category_id: json['category_id'] ?? 0,
        category: json['category'] ?? '',
        description: json['description'],
        createdAt: DateTime.parse(
            json['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(
            json['updatedAt'] ?? DateTime.now().toIso8601String()),
        imageUrl: json['image'],
        clientId: json['clientId'],
        priceOptions: (json['priceOptions'] as List<dynamic>?)
                ?.map((e) => PriceOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        storeQuantities: (json['storeQuantities'] as List<dynamic>?)
                ?.map((e) => StoreQuantity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        packSize: json['packSize'],
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
      'name': name,
      'category_id': category_id,
      'category': category,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'image': imageUrl,
      'clientId': clientId,
      'priceOptions': priceOptions.map((e) => e.toJson()).toList(),
      'storeQuantities': storeQuantities.map((e) => e.toJson()).toList(),
      if (packSize != null) 'packSize': packSize,
    };
  }

  // Helper method to get quantity for a specific store
  int getQuantityForStore(int storeId) {
    final storeQuantity = storeQuantities.firstWhere(
      (sq) => sq.storeId == storeId,
      orElse: () =>
          StoreQuantity(id: 0, storeId: storeId, productId: id, quantity: 0),
    );
    return storeQuantity.quantity;
  }

  // Helper method to get maximum quantity available in a region
  int getMaxQuantityInRegion(int regionId) {
    // Early return if no store quantities
    if (storeQuantities.isEmpty) {
      return 0;
    }

    int maxQuantity = 0;

    // Single pass through store quantities
    for (final sq in storeQuantities) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  static Product defaultProduct() {
    return Product(
      id: 0,
      name: 'Unknown',
      category_id: 0,
      category: 'Unknown',
      description: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: '',
      clientId: null,
      priceOptions: [],
      storeQuantities: [],
      packSize: null,
    );
  }
}
