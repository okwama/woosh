import 'package:hive/hive.dart';
import 'package:woosh/models/hive/product_model.dart';
import 'package:woosh/models/product_model.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Ensure the adapter is registered
void ensureProductHiveAdapterRegistered() {
  try {
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(ProductHiveModelAdapter());
      debugPrint('ProductHiveModelAdapter registered manually');
    } else {
      debugPrint('ProductHiveModelAdapter already registered');
    }
  } catch (e) {
    debugPrint('Error registering ProductHiveModelAdapter: $e');
  }
}

class ProductHiveService {
  static const String _boxName = 'products';
  static const String _timestampBoxName = 'timestamps';
  
  Box<ProductHiveModel>? _productBox;
  Box? _timestampBox;
  
  // Flag to track initialization status
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    // If already initializing, wait for that to complete
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    // If already initialized, return immediately
    if (_isInitialized) {
      return;
    }
    
    // Create a completer to track initialization
    _initCompleter = Completer<void>();
    
    try {
      // Ensure adapter is registered
      ensureProductHiveAdapterRegistered();
      
      debugPrint('ProductHiveService: Starting initialization');
      
      // Open the products box if not already open
      if (!Hive.isBoxOpen(_boxName)) {
        debugPrint('ProductHiveService: Opening products box');
        _productBox = await Hive.openBox<ProductHiveModel>(_boxName);
      } else {
        debugPrint('ProductHiveService: Products box already open');
        _productBox = Hive.box<ProductHiveModel>(_boxName);
      }
      
      // Open the timestamps box if not already open
      if (!Hive.isBoxOpen(_timestampBoxName)) {
        debugPrint('ProductHiveService: Opening timestamps box');
        _timestampBox = await Hive.openBox(_timestampBoxName);
      } else {
        debugPrint('ProductHiveService: Timestamps box already open');
        _timestampBox = Hive.box(_timestampBoxName);
      }
      
      _isInitialized = true;
      debugPrint('ProductHiveService: Initialization complete');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('ProductHiveService: Error during initialization: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }
  
  // Helper method to ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      print('ProductHiveService: Not initialized, initializing now');
      await init();
    }
  }

  // Save a single product
  Future<void> saveProduct(Product product) async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot save product, box is null');
      return;
    }
    
    try {
      final hiveModel = ProductHiveModel.fromProduct(product);
      await _productBox!.put(product.id, hiveModel);
      print('ProductHiveService: Saved product ${product.id}');
    } catch (e) {
      print('ProductHiveService: Error saving product: $e');
      rethrow;
    }
  }

  // Save multiple products
  Future<void> saveProducts(List<Product> products) async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot save products, box is null');
      return;
    }
    
    try {
      final Map<int, ProductHiveModel> productMap = {
        for (var product in products) 
          product.id: ProductHiveModel.fromProduct(product)
      };
      await _productBox!.putAll(productMap);
      print('ProductHiveService: Saved ${products.length} products');
    } catch (e) {
      print('ProductHiveService: Error saving products: $e');
      rethrow;
    }
  }

  // Get a single product by ID
  Future<Product?> getProduct(int id) async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot get product, box is null');
      return null;
    }
    
    try {
      final hiveModel = _productBox!.get(id);
      return hiveModel?.toProduct();
    } catch (e) {
      print('ProductHiveService: Error getting product: $e');
      return null;
    }
  }

  // Get all products
  Future<List<Product>> getAllProducts() async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot get all products, box is null');
      return [];
    }
    
    try {
      return _productBox!.values.map((hiveModel) => hiveModel.toProduct()).toList();
    } catch (e) {
      print('ProductHiveService: Error getting all products: $e');
      return [];
    }
  }

  // Get products by search query
  Future<List<Product>> searchProducts(String query) async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot search products, box is null');
      return [];
    }
    
    try {
      final lowercaseQuery = query.toLowerCase();
      return _productBox!.values
          .where((model) => 
              model.name.toLowerCase().contains(lowercaseQuery) ||
              (model.description?.toLowerCase().contains(lowercaseQuery) ?? false))
          .map((hiveModel) => hiveModel.toProduct())
          .toList();
    } catch (e) {
      print('ProductHiveService: Error searching products: $e');
      return [];
    }
  }

  // Delete a product
  Future<void> deleteProduct(int id) async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot delete product, box is null');
      return;
    }
    
    try {
      await _productBox!.delete(id);
      print('ProductHiveService: Deleted product $id');
    } catch (e) {
      print('ProductHiveService: Error deleting product: $e');
      rethrow;
    }
  }

  // Clear all products
  Future<void> clearAllProducts() async {
    await _ensureInitialized();
    if (_productBox == null) {
      print('ProductHiveService: Cannot clear products, box is null');
      return;
    }
    
    try {
      await _productBox!.clear();
      print('ProductHiveService: Cleared all products');
    } catch (e) {
      print('ProductHiveService: Error clearing products: $e');
      rethrow;
    }
  }

  // Get the timestamp of the last update
  Future<DateTime?> getLastUpdateTime() async {
    await _ensureInitialized();
    if (_timestampBox == null) {
      print('ProductHiveService: Cannot get last update time, timestamps box is null');
      return null;
    }
    
    try {
      final timestamp = _timestampBox!.get('products_last_update');
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      print('ProductHiveService: Error getting last update time: $e');
      return null;
    }
  }

  // Set the timestamp of the last update
  Future<void> setLastUpdateTime(DateTime timestamp) async {
    await _ensureInitialized();
    if (_timestampBox == null) {
      print('ProductHiveService: Cannot set last update time, timestamps box is null');
      return;
    }
    
    try {
      await _timestampBox!.put('products_last_update', timestamp.millisecondsSinceEpoch);
      print('ProductHiveService: Updated last update timestamp');
    } catch (e) {
      print('ProductHiveService: Error setting last update time: $e');
      rethrow;
    }
  }
}
