import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:woosh/models/hive/product_report_hive_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/hive/product_report_hive_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductReportPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onReportSubmitted;
  final List<Product>? preloadedProducts;

  const ProductReportPage({
    super.key,
    required this.journeyPlan,
    this.onReportSubmitted,
    this.preloadedProducts,
  });

  static Future<List<Product>> preloadProducts() async {
    try {
      final products = await ApiService.getProducts(page: 1, limit: 20);
      return products;
    } catch (e) {
      print('Error preloading products: $e');
      return [];
    }
  }

  @override
  State<ProductReportPage> createState() => _ProductReportPageState();
}

class _ProductReportPageState extends State<ProductReportPage> {
  final _commentController = TextEditingController();
  final _apiService = ApiService();
  late final ProductReportHiveService _productReportHiveService;
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Product> _products = [];
  Map<int, int> _productQuantities = {}; // Map of productId to quantity
  Map<int, TextEditingController> _quantityControllers =
      {}; // Controllers for quantity fields
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMoreProducts = true;
  final ScrollController _scrollController = ScrollController();
  bool _isOnline = true;
  bool _hasUnsyncedData = false;
  bool _isUsingCachedData = false;
  DateTime? _lastProductUpdate;

  @override
  void initState() {
    super.initState();
    _initHiveService();
    _checkConnectivity();
    _loadProductsWithCache();
    _scrollController.addListener(_onScroll);

    // Listen for connectivity changes
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
      if (_isOnline && _hasUnsyncedData) {
        _syncUnsyncedReports();
      }
    });
  }

  Future<void> _initHiveService() async {
    try {
      // Ensure adapters are registered
      if (!Hive.isAdapterRegistered(10)) {
        // 10 is the typeId for ProductReportHiveModel
        Hive.registerAdapter(ProductReportHiveModelAdapter());
      }

      if (!Hive.isAdapterRegistered(11)) {
        // 11 is the typeId for ProductQuantityHiveModel
        Hive.registerAdapter(ProductQuantityHiveModelAdapter());
      }

      // Try to get the already registered service
      try {
        _productReportHiveService = Get.find<ProductReportHiveService>();
      } catch (e) {
        // If not found, initialize it
        _productReportHiveService = ProductReportHiveService();
        await _productReportHiveService.init();
        Get.put(_productReportHiveService);
      }

      // Only load existing report after service is properly initialized
      // and we're sure the journey plan ID is not null
      if (widget.journeyPlan.id != null) {
        _loadExistingReport();
      }
    } catch (e) {
      print('Error initializing Hive service: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivity = Connectivity();
    var connectivityResult = await connectivity.checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  void _loadExistingReport() {
    // Add null check for journeyPlan.id
    final journeyPlanId = widget.journeyPlan.id;
    if (journeyPlanId == null) return;

    final savedReport =
        _productReportHiveService.getReportByJourneyPlanId(journeyPlanId);
    if (savedReport != null && !savedReport.isSynced) {
      setState(() {
        _hasUnsyncedData = true;
        _commentController.text = savedReport.comment;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    // Dispose all quantity controllers
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreProducts) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProductsWithCache() async {
    try {
      setState(() => _isLoading = true);

      // Use preloaded products if available
      if (widget.preloadedProducts != null &&
          widget.preloadedProducts!.isNotEmpty) {
        _setupProductsState(widget.preloadedProducts!);
        return;
      }

      // Check if we have cached products and if they're fresh (less than 24 hours old)
      final cachedProducts = await _getCachedProducts();
      final shouldUseCache = _shouldUseCachedProducts();

      if (cachedProducts.isNotEmpty && shouldUseCache) {
        // Use cached data
        setState(() {
          _isUsingCachedData = true;
          _isLoading = false;
        });
        _setupProductsState(cachedProducts);

        // Load fresh data in background if online
        if (_isOnline) {
          _loadFreshProductsInBackground();
        }
      } else if (_isOnline) {
        // Load fresh data from API
        final products =
            await ApiService.getProducts(page: 1, limit: _pageSize);
        await _cacheProducts(products);
        _setupProductsState(products);
      } else {
        // Offline mode - use cached data even if stale
        if (cachedProducts.isNotEmpty) {
          setState(() {
            _isUsingCachedData = true;
            _isLoading = false;
          });
          _setupProductsState(cachedProducts);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Using cached products. Refresh when online for latest data.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No cached products available. Please connect to internet.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Load saved quantities from Hive if available
      _loadSavedQuantities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load products. Please try again.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadProductsWithCache,
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Product>> _getCachedProducts() async {
    try {
      final box = GetStorage();
      final cachedData = box.read('cached_products');
      final lastUpdate = box.read('products_last_update');

      if (cachedData != null && lastUpdate != null) {
        _lastProductUpdate = DateTime.parse(lastUpdate);
        return List<Product>.from(cachedData.map((x) => Product.fromJson(x)));
      }
    } catch (e) {
      print('Error reading cached products: $e');
    }
    return [];
  }

  Future<void> _cacheProducts(List<Product> products) async {
    try {
      final box = GetStorage();
      final productsJson = products.map((p) => p.toJson()).toList();
      await box.write('cached_products', productsJson);
      await box.write('products_last_update', DateTime.now().toIso8601String());
      _lastProductUpdate = DateTime.now();
    } catch (e) {
      print('Error caching products: $e');
    }
  }

  bool _shouldUseCachedProducts() {
    if (_lastProductUpdate == null) return false;

    // Use cache if data is less than 24 hours old
    final cacheAge = DateTime.now().difference(_lastProductUpdate!);
    return cacheAge.inHours < 24;
  }

  Future<void> _loadFreshProductsInBackground() async {
    try {
      final products = await ApiService.getProducts(page: 1, limit: _pageSize);
      await _cacheProducts(products);

      if (mounted && _isUsingCachedData) {
        setState(() {
          _isUsingCachedData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Products updated in background'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Background product update failed: $e');
    }
  }

  void _setupProductsState(List<Product> products) {
    if (mounted) {
      setState(() {
        _products = products;
        _productQuantities = {for (var product in products) product.id: 0};
        _quantityControllers = {
          for (var product in products)
            product.id: TextEditingController(text: '0')
        };
        _isLoading = false;
        _hasMoreProducts = products.length == _pageSize;
      });
    }
  }

  void _loadSavedQuantities() {
    // Add null check for journeyPlan.id before using it
    if (widget.journeyPlan.id == null) return;

    final savedReport = _productReportHiveService
        .getReportByJourneyPlanId(widget.journeyPlan.id!);
    if (savedReport != null) {
      // Update quantities from saved report
      for (var product in savedReport.products) {
        // Check if productId is not null before using it
        if (_productQuantities.containsKey(product.productId)) {
          setState(() {
            // Use null-aware operators to safely handle nullable values
            _productQuantities[product.productId] = product.quantity ?? 0;
            _quantityControllers[product.productId]?.text =
                (product.quantity ?? 0).toString();
          });
        }
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final moreProducts =
          await ApiService.getProducts(page: nextPage, limit: _pageSize);

      if (!mounted) return;

      setState(() {
        _products.addAll(moreProducts);
        _productQuantities
            .addAll({for (var product in moreProducts) product.id: 0});
        _quantityControllers.addAll({
          for (var product in moreProducts)
            product.id: TextEditingController(text: '0')
        });
        _currentPage = nextPage;
        _hasMoreProducts = moreProducts.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to load more products'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadMoreProducts,
          ),
        ),
      );
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreProducts = true;
      _products.clear();
      _productQuantities.clear();
      _quantityControllers.clear();
      _isUsingCachedData = false;
    });

    try {
      final products = await ApiService.getProducts(page: 1, limit: _pageSize);
      await _cacheProducts(products);
      _setupProductsState(products);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Products refreshed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to refresh products'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _refreshProducts,
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    // Check if at least one product has a quantity > 0
    bool hasQuantities = _productQuantities.values.any((qty) => qty > 0);
    if (!hasQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter quantities for at least one product')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Optimistically show success and navigate back
      widget.onReportSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      // Save to Hive first (works offline)
      await _saveReportToHive();

      // If online, try to submit to API
      if (_isOnline) {
        await _submitReportToApi();
      } else {
        // If offline, show message that it will sync later
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Report saved offline. Will sync when connection is available.')),
          );
          setState(() => _hasUnsyncedData = true);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Unable to save report';
        if (e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('connection')) {
          errorMessage =
              'No internet connection. Report will sync when online.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitReport,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _saveReportToHive() async {
    // Ensure journeyPlanId is not null before proceeding
    final journeyPlanId = widget.journeyPlan.id;
    if (journeyPlanId == null) {
      // Handle the null case - perhaps log an error or show a message
      print('Cannot save report: Journey Plan ID is null');
      return;
    }

    try {
      await _productReportHiveService.saveProductReport(
        journeyPlanId: journeyPlanId,
        clientId: widget.journeyPlan.client.id,
        clientName: widget.journeyPlan.client.name,
        clientAddress: widget.journeyPlan.client.address,
        products: _products,
        quantities: _productQuantities,
        comment: _commentController.text,
      );
    } catch (e) {
      print('Error saving report to Hive: $e');
      // Re-throw to allow the calling method to handle it
      rethrow;
    }
  }

  Future<void> _submitReportToApi() async {
    final box = GetStorage();
    final salesRepData = box.read('salesRep');
    final salesRepId =
        salesRepData is Map<String, dynamic> ? salesRepData['id'] as int : 0;

    if (salesRepId == 0) {
      throw Exception(
          "User not authenticated: Could not determine salesRep ID");
    }

    // Create a list of product reports for products with quantities > 0
    final productReports = _products
        .where((product) => _productQuantities[product.id]! > 0)
        .map((product) => ProductReport(
              reportId: 0,
              productName: product.name,
              productId: product.id,
              quantity: _productQuantities[product.id]!,
              comment: _commentController.text,
            ))
        .toList();

    // Create the report with the product reports
    final report = Report(
      type: ReportType.PRODUCT_AVAILABILITY,
      journeyPlanId: widget.journeyPlan.id,
      salesRepId: salesRepId,
      clientId: widget.journeyPlan.client.id,
      productReports: productReports,
    );

    await _apiService.submitReport(report);

    // Mark as synced in Hive
    final journeyPlanId = widget.journeyPlan.id;
    if (journeyPlanId != null) {
      await _productReportHiveService.markAsSynced(journeyPlanId);
      setState(() => _hasUnsyncedData = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
      widget.onReportSubmitted?.call();
      Navigator.pop(context);
    }
  }

  Future<void> _syncUnsyncedReports() async {
    final unsyncedReports = _productReportHiveService.getUnsyncedReports();
    if (unsyncedReports.isEmpty) return;

    final box = GetStorage();
    final salesRepData = box.read('salesRep');
    final salesRepId =
        salesRepData is Map<String, dynamic> ? salesRepData['id'] as int : 0;

    if (salesRepId == 0) return;

    for (var report in unsyncedReports) {
      try {
        final apiReport =
            _productReportHiveService.convertToReportModel(report, salesRepId);
        await _apiService.submitReport(apiReport);
        await _productReportHiveService.markAsSynced(report.journeyPlanId);
      } catch (e) {
        print('Error syncing report: $e');
        // Continue with next report even if this one fails
      }
    }

    setState(() => _hasUnsyncedData = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Product Availability Report',
        actions: [
          if (_isUsingCachedData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_download,
                    color: Colors.orange.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cached',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
            onPressed: _isLoading ? null : _refreshProducts,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outlet Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.journeyPlan.client.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.journeyPlan.client.address,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cache Status Card (if using cached data)
            if (_isUsingCachedData) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Using cached products. Tap refresh for latest data.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshProducts,
                        child: Text(
                          'Refresh',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Product Report Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_products.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'No products available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _refreshProducts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Products Table
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Product',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  _products.length + (_hasMoreProducts ? 1 : 0),
                              separatorBuilder: (context, index) => Divider(
                                  height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                if (index == _products.length) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }

                                final product = _products[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: TextField(
                                            controller: _quantityControllers[
                                                product.id],
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setState(() {
                                                _productQuantities[product.id] =
                                                    int.tryParse(value) ?? 0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comment',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit Report'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
