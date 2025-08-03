import 'dart:convert';
import 'lib/models/product_model.dart';

void main() {
  print('🧪 Testing Product.fromJson parsing...');

  // Sample product data from the API
  final sampleProduct = {
    "id": 7,
    "productCode": "Australian Ice Mango",
    "productName": "Australian Ice Mango 3000puffs",
    "description": null,
    "categoryId": 1,
    "category": "3000 puffs",
    "unitOfMeasure": "PCS",
    "costPrice": 45,
    "sellingPrice": 85,
    "taxType": "16%",
    "reorderLevel": 30,
    "currentStock": 49,
    "isActive": true,
    "imageUrl":
        "https://res.cloudinary.com/otienobryan/image/upload/v1752784480/products/product_7_1752784478562.png",
    "createdAt": "2025-07-06T09:32:52.000Z",
    "updatedAt": "2025-07-22T10:15:02.000Z"
  };

  try {
    print('📦 Testing with sample product data...');
    final product = Product.fromJson(sampleProduct);

    print('✅ Product parsed successfully!');
    print('📦 Product ID: ${product.id}');
    print('📦 Product Name: ${product.productName}');
    print('📦 Cost Price: ${product.costPrice}');
    print('📦 Selling Price: ${product.sellingPrice}');
    print('📦 Current Stock: ${product.currentStock}');
    print('📦 Is Active: ${product.isActive}');
  } catch (e, stackTrace) {
    print('❌ Error parsing product: $e');
    print('❌ Stack trace: $stackTrace');
  }
}
