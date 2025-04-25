class Product {
  final int id;
  final String name;
  final int category_id;
  final String category;
  final String description;
  final int? currentStock;
  final int? reorderPoint; // Nullable as per Prisma schema
  final int orderQuantity; // Defaulting this to 0 if Prisma has a default
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final int? clientId;

  Product({
    required this.id,
    required this.name,
    required this.category_id,
    required this.category,
    this.description = '',
    this.currentStock,
    this.reorderPoint, // Nullable field
    this.orderQuantity = 0, // Default 0 if not provided
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.clientId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      category_id: json['category_id'],
      category: json['category'],
      description: json['description'] ?? '',
      currentStock: json['currentStock'],
      reorderPoint: json['reorderPoint'],
      orderQuantity: json['orderQuantity'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      imageUrl: json['image'],
      clientId: json['clientId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': category_id,
      'category': category,
      'description': description,
      'currentStock': currentStock,
      'reorderPoint': reorderPoint,
      'orderQuantity': orderQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'image': imageUrl,
      'clientId': clientId,
    };
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
      currentStock: 0,
      reorderPoint: 0,
      orderQuantity: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: '',
      clientId: null,
    );
  }
}
