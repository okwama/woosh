import 'price_option_model.dart';
import 'store_quantity_model.dart';

class Product {
  final int id;
  final String name;
  final int category_id;
  final String category;
  final String description;
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
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.clientId,
    this.priceOptions = const [],
    this.storeQuantities = const [],
    this.packSize,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      category_id: json['category_id'],
      category: json['category'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
    print('Checking stock for region $regionId');
    print('Total store quantities: ${storeQuantities.length}');

    // Filter store quantities for stores in the specified region
    final regionStoreQuantities = storeQuantities.where((sq) {
      final store = sq.store;
      final matches = store != null && store.regionId == regionId;
      print(
          'Store ${sq.storeId}: region=${store?.regionId}, quantity=${sq.quantity}, matches=$matches');
      return matches;
    }).toList();

    print(
        'Found ${regionStoreQuantities.length} stores in region with product');

    if (regionStoreQuantities.isEmpty) {
      print('No stores found in region $regionId');
      return 0; // No stores in the region have this product
    }

    // Find the maximum quantity among stores in the region
    final maxQuantity = regionStoreQuantities.fold<int>(
      0,
      (max, sq) => sq.quantity > max ? sq.quantity : max,
    );

    print('Maximum quantity in region: $maxQuantity');
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
