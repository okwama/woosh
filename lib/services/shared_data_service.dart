import 'package:get/get.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/report/report_service.dart';
import 'package:get_storage/get_storage.dart';

/// Shared Data Service - Manages shared data across the app
///
/// This service prevents redundant API calls by:
/// - Caching products globally
/// - Managing report data
/// - Providing shared state management
class SharedDataService extends GetxController {
  // Observable variables
  final products = <Product>[].obs;
  final reports = <Report>[].obs;
  final isLoading = false.obs;
  final lastProductUpdate = Rxn<DateTime>();
  final lastReportUpdate = Rxn<DateTime>();

  // Cache settings
  static const Duration _productCacheDuration = Duration(hours: 24);
  static const Duration _reportCacheDuration = Duration(minutes: 30);

  @override
  void onInit() {
    super.onInit();
    // Load products on app start
    loadProducts();
  }

  /// Load products with caching
  Future<void> loadProducts({bool forceRefresh = false}) async {
    try {
      // Check if we have fresh cached data
      if (!forceRefresh && _shouldUseCachedProducts()) {
        print('📦 Using cached products');
        return;
      }

      isLoading.value = true;
      print('📦 Loading products from API...');

      final fetchedProducts = await ApiService.getProducts(page: 1, limit: 200);

      products.value = fetchedProducts;
      lastProductUpdate.value = DateTime.now();

      print('✅ Loaded ${fetchedProducts.length} products');
    } catch (e) {
      print('❌ Failed to load products: $e');

      // If we have cached products, keep them and show a warning
      if (products.isNotEmpty) {
        print('⚠️ Using cached products due to API error');
      } else {
        print('⚠️ No cached products available');
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if cached products are still valid
  bool _shouldUseCachedProducts() {
    if (products.isEmpty) return false;
    if (lastProductUpdate.value == null) return false;

    final now = DateTime.now();
    final lastUpdate = lastProductUpdate.value!;
    final difference = now.difference(lastUpdate);

    return difference < _productCacheDuration;
  }

  /// Get products (cached or fresh)
  List<Product> getProducts() {
    return products;
  }

  /// Load reports for a specific journey plan
  Future<void> loadReportsForJourneyPlan(int journeyPlanId) async {
    try {
      print('📝 Loading reports for journey plan: $journeyPlanId');

      final reportsData =
          await ReportsService.getReportsByJourneyPlan(journeyPlanId);

      // Convert the response to Report objects
      final List<Report> reportList = [];

      if (reportsData['feedbackReports'] != null) {
        for (final reportData in reportsData['feedbackReports']) {
          try {
            final report = Report.fromJson(reportData);
            reportList.add(report);
          } catch (e) {
            print('⚠️ Could not parse feedback report: $e');
          }
        }
      }

      if (reportsData['productReports'] != null) {
        for (final reportData in reportsData['productReports']) {
          try {
            final report = Report.fromJson(reportData);
            reportList.add(report);
          } catch (e) {
            print('⚠️ Could not parse product report: $e');
          }
        }
      }

      if (reportsData['visibilityReports'] != null) {
        for (final reportData in reportsData['visibilityReports']) {
          try {
            final report = Report.fromJson(reportData);
            reportList.add(report);
          } catch (e) {
            print('⚠️ Could not parse visibility report: $e');
          }
        }
      }

      reports.value = reportList;
      lastReportUpdate.value = DateTime.now();

      print('✅ Loaded ${reportList.length} reports');
    } catch (e) {
      print('❌ Failed to load reports: $e');
    }
  }

  /// Get reports for a journey plan (cached or fresh)
  List<Report> getReportsForJourneyPlan(int journeyPlanId) {
    // Check if we have fresh cached data
    if (_shouldUseCachedReports()) {
      return reports;
    }

    // Load fresh data in background
    loadReportsForJourneyPlan(journeyPlanId);
    return reports;
  }

  /// Check if cached reports are still valid
  bool _shouldUseCachedReports() {
    if (reports.isEmpty) return false;
    if (lastReportUpdate.value == null) return false;

    final now = DateTime.now();
    final lastUpdate = lastReportUpdate.value!;
    final difference = now.difference(lastUpdate);

    return difference < _reportCacheDuration;
  }

  /// Clear all cached data
  void clearCache() {
    products.clear();
    reports.clear();
    lastProductUpdate.value = null;
    lastReportUpdate.value = null;
  }

  /// Cache reports for a specific journey plan
  Future<void> cacheReports(List<Report> reports) async {
    try {
      final box = GetStorage();
      final journeyPlanId =
          reports.isNotEmpty ? reports.first.journeyPlanId : null;
      if (journeyPlanId == null) return;

      final key = 'jp_reports_cache_$journeyPlanId';
      final reportsJson = reports.map((r) => r.toJson()).toList();
      await box.write(key, reportsJson);
    } catch (e) {
      print('❌ Failed to cache reports: $e');
    }
  }

  /// Clear all caches (for backward compatibility)
  Future<void> clearAllCaches() async {
    try {
      final box = GetStorage();
      final keysToRemove = <String>[];
      final allKeys = box.getKeys();

      for (final key in allKeys) {
        // Only clear JP-specific and reports caches
        // DO NOT clear product cache since products don't change
        if (key.toString().contains('jp_reports_cache_') ||
            key.toString().contains('reports_')) {
          keysToRemove.add(key.toString());
        }
      }

      for (final key in keysToRemove) {
        await box.remove(key);
      }
    } catch (e) {
      print('❌ Failed to clear caches: $e');
    }
  }

  /// Refresh all data
  Future<void> refreshAllData() async {
    await loadProducts(forceRefresh: true);
  }

  /// Get product by ID
  Product? getProductById(int id) {
    try {
      return products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;

    final lowercaseQuery = query.toLowerCase();
    return products.where((product) {
      return product.productName.toLowerCase().contains(lowercaseQuery) ||
          (product.category?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Check if data is loading
  bool get isDataLoading => isLoading.value;

  /// Get product count
  int get productCount => products.length;

  /// Get report count
  int get reportCount => reports.length;
}
