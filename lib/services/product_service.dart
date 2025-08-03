import 'package:get/get.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/shared_data_service.dart';

class ProductService extends GetxController {
  late final SharedDataService _sharedDataService;

  @override
  void onInit() {
    super.onInit();
    _sharedDataService = Get.find<SharedDataService>();
  }

  /// Get products with caching
  Future<List<Product>> getProducts() async {
    try {
      // Use shared data service for caching
      final products = _sharedDataService.getProducts();
      if (products.isNotEmpty) {
        return products;
      }

      // If shared service doesn't have products, load them
      await _sharedDataService.loadProducts();
      return _sharedDataService.getProducts();
    } catch (e) {
      print('❌ Failed to get products: $e');
      return [];
    }
  }

  /// Get products with force refresh
  Future<List<Product>> getProductsWithRefresh() async {
    try {
      await _sharedDataService.loadProducts(forceRefresh: true);
      return _sharedDataService.getProducts();
    } catch (e) {
      print('❌ Failed to refresh products: $e');
      return [];
    }
  }

  /// Search products
  List<Product> searchProducts(String query) {
    return _sharedDataService.searchProducts(query);
  }

  /// Get product by ID
  Product? getProductById(int id) {
    return _sharedDataService.getProductById(id);
  }
}
