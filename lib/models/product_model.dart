
class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final int currentStock;
  final int reorderPoint;
  final int orderQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description = '', // Default empty string if no description provided
    required this.price,
    required this.currentStock,
    required this.reorderPoint,
    required this.orderQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '', // Handle potential null descriptions
      price: (json['price'] as num).toDouble(),
      currentStock: json['currentStock'],
      reorderPoint: json['reorderPoint'],
      orderQuantity: json['orderQuantity'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currentStock': currentStock,
      'reorderPoint': reorderPoint,
      'orderQuantity': orderQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
      description: '',
      price: 0,
      currentStock: 0,
      reorderPoint: 0,
      orderQuantity: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}