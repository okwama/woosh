import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:woosh/models/hive/product_report_hive_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/product_report_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/report/report_service.dart';
import 'package:woosh/services/hive/product_report_hive_service.dart';
import 'package:woosh/services/shared_data_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';

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
      final sharedDataService = Get.find<SharedDataService>();
      await sharedDataService.loadProducts();
      return sharedDataService.getProducts();
    } catch (e) {
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
  late final SharedDataService _sharedDataService;
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
  final TextEditingController _searchController = TextEditingController();
  bool _isOnline = true;
  bool _hasUnsyncedData = false;
  bool _isUsingCachedData = false;
  DateTime? _lastProductUpdate;
  List<Product> _allProducts = []; // Store all products for search
  List<Product> _filteredProducts = []; // Display filtered products
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _sharedDataService = Get.find<SharedDataService>();
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

        // Check if the service is properly initialized
        if (!_productReportHiveService.isReady) {
          print(
              '⚠️ ProductReportHiveService found but not ready, reinitializing...');
          await _productReportHiveService.init();
        }
      } catch (e) {
        print('⚠️ ProductReportHiveService not found, initializing...');
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
      print('⚠️ Error initializing ProductReportHiveService: $e');
      // Continue without the service - the app should still work
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

    try {
      // Check if the service is ready before accessing it
      if (_productReportHiveService.isReady) {
        final savedReport =
            _productReportHiveService.getReportByJourneyPlanId(journeyPlanId);
        if (savedReport != null && !savedReport.isSynced) {
          setState(() {
            _hasUnsyncedData = true;
            _commentController.text = savedReport.comment;
          });
        }
      } else {
        print(
            '⚠️ ProductReportHiveService not ready, skipping existing report load');
      }
    } catch (e) {
      print('⚠️ Error loading existing report: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _searchController.dispose();
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

      // Use shared data service instead of individual API calls
      final products = _sharedDataService.getProducts();

      if (products.isNotEmpty) {
        // Use shared products
        setState(() {
          _isUsingCachedData = true;
          _isLoading = false;
        });
        _setupProductsState(products);
      } else {
        // If shared service doesn't have products, load them
        await _sharedDataService.loadProducts();
        final freshProducts = _sharedDataService.getProducts();

        if (freshProducts.isNotEmpty) {
          setState(() {
            _isUsingCachedData = false;
            _isLoading = false;
          });
          _setupProductsState(freshProducts);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No products available. Please try again.'),
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
          ),
        );
      }
    }
  }

  void _setupProductsState(List<Product> products) {
    if (mounted) {
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _products = products; // Keep for backward compatibility
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

  void _onSearchChanged(String query) {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    if (query.isEmpty) {
      if (mounted) {
      setState(() {
        _filteredProducts = _allProducts;
        _isSearching = false;
      });
      }
      return;
    }

    final searchTerms = query.toLowerCase().split(' ');
    final filtered = _allProducts.where((product) {
      final name = product.productName.toLowerCase();
      final description = (product.description ?? '').toLowerCase();

      return searchTerms
          .every((term) => name.contains(term) || description.contains(term));
    }).toList();

    if (mounted) {
    setState(() {
      _filteredProducts = filtered;
      _isSearching = false;
    });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
    setState(() {
      _filteredProducts = _allProducts;
      _isSearching = false;
    });
    }
  }

  void _clearAllQuantities() {
    if (mounted) {
    setState(() {
      for (var product in _allProducts) {
        _productQuantities[product.id] = 0;
        _quantityControllers[product.id]?.text = '0';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All quantities cleared'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    }
  }

  void _copyFromPreviousReport() async {
    try {
      // Check if the service is ready before accessing it
      if (!_productReportHiveService.isReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service not ready, please try again'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Get the most recent report for this client
      final recentReport = _productReportHiveService.getRecentReportByClientId(
        widget.journeyPlan.client.id,
      );

      if (recentReport != null) {
        if (mounted) {
        setState(() {
          for (var product in recentReport.products) {
            if (_productQuantities.containsKey(product.productId)) {
                _productQuantities[product.productId] = product.quantity;
              _quantityControllers[product.productId]?.text =
                    product.quantity.toString();
            }
          }
        });
        }

        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Copied quantities from ${DateFormat('MMM dd, yyyy').format(recentReport.createdAt)}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        }
      } else {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous report found for this client'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        }
      }
    } catch (e) {
      print('⚠️ Error copying from previous report: $e');
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error copying from previous report'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      }
    }
  }

  void _loadSavedQuantities() {
    // Add null check for journeyPlan.id before using it
    if (widget.journeyPlan.id == null) return;

    try {
      // Check if the service is ready before accessing it
      if (!_productReportHiveService.isReady) {
        print(
            '⚠️ ProductReportHiveService not ready, skipping saved quantities load');
        return;
      }

      final savedReport = _productReportHiveService
          .getReportByJourneyPlanId(widget.journeyPlan.id!);
      if (savedReport != null) {
        // Update quantities from saved report
        for (var product in savedReport.products) {
          // Check if productId is not null before using it
          if (_productQuantities.containsKey(product.productId)) {
            if (mounted) {
            setState(() {
              // Use null-aware operators to safely handle nullable values
                _productQuantities[product.productId] = product.quantity;
              _quantityControllers[product.productId]?.text =
                    product.quantity.toString();
            });
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading saved quantities: $e');
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;

    setState(() => _isLoadingMore = true);

    try {
      // Since we're using shared data service, we don't need pagination
      // All products are loaded at once
      setState(() {
        _isLoadingMore = false;
        _hasMoreProducts = false; // No more products to load
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
      // Use shared data service to refresh products
      await _sharedDataService.loadProducts(forceRefresh: true);
      final products = _sharedDataService.getProducts();
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

    // Check if all products have zero quantities
    bool allZero = _productQuantities.values.every((qty) => qty == 0);
    bool hasComment = _commentController.text.trim().isNotEmpty;

    // If all products are zero, require a comment
    if (allZero && !hasComment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please add a comment when reporting zero quantities for all products'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save to Hive first (works offline)
      await _saveReportToHive();

      // Show success message and navigate back
      if (mounted) {
      widget.onReportSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
      }

      // If online, try to submit to API in background
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
      return;
    }

    try {
      // Check if the service is ready before accessing it
      if (!_productReportHiveService.isReady) {
        throw StateError('ProductReportHiveService is not ready');
      }

      await _productReportHiveService.saveProductReport(
        journeyPlanId: journeyPlanId,
        clientId: widget.journeyPlan.client.id,
        clientName: widget.journeyPlan.client.name,
        clientAddress: widget.journeyPlan.client.address ?? '',
        products: _products,
        quantities: _productQuantities,
        comment: _commentController.text,
      );
    } catch (e) {
      print('⚠️ Error saving report to Hive: $e');
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
        .where((product) => (_productQuantities[product.id] ?? 0) > 0)
        .map((product) => ProductReport(
              reportId: 0,
              productName: product.productName,
              productId: product.id,
              quantity: _productQuantities[product.id] ?? 0,
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

    await ReportsService.submitReport(report);

    // Mark as synced in Hive
    final journeyPlanId = widget.journeyPlan.id;
    if (journeyPlanId != null) {
      try {
        // Check if the service is ready before accessing it
        if (_productReportHiveService.isReady) {
          await _productReportHiveService.markAsSynced(journeyPlanId);
          if (mounted) {
          setState(() => _hasUnsyncedData = false);
          }
        } else {
          print('⚠️ ProductReportHiveService not ready, skipping sync mark');
        }
      } catch (e) {
        print('⚠️ Error marking report as synced: $e');
      }
    }
  }

  Future<void> _syncUnsyncedReports() async {
    try {
      // Check if the service is ready before accessing it
      if (!_productReportHiveService.isReady) {
        print(
            '⚠️ ProductReportHiveService not ready, skipping unsynced reports sync');
        return;
      }

      final unsyncedReports = _productReportHiveService.getUnsyncedReports();
      if (unsyncedReports.isEmpty) return;

      final box = GetStorage();
      final salesRepData = box.read('salesRep');
      final salesRepId =
          salesRepData is Map<String, dynamic> ? salesRepData['id'] as int : 0;

      if (salesRepId == 0) return;

      for (var report in unsyncedReports) {
        try {
          final apiReport = _productReportHiveService.convertToReportModel(
              report, salesRepId);
          await ReportsService.submitReport(apiReport);
          await _productReportHiveService.markAsSynced(report.journeyPlanId);
        } catch (e) {
          print('⚠️ Error syncing report ${report.journeyPlanId}: $e');
          // Continue with next report even if this one fails
        }
      }

      if (mounted) {
      setState(() => _hasUnsyncedData = false);
      }
    } catch (e) {
      print('⚠️ Error syncing unsynced reports: $e');
    }
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
                      widget.journeyPlan.client.address ?? '',
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

            // Search Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_isSearching) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Search Results Count
            if (_searchController.text.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_filteredProducts.length} of ${_allProducts.length} products',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Quick Actions
            if (!_isLoading && _allProducts.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearAllQuantities,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyFromPreviousReport,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Previous'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

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
                              itemCount: _filteredProducts.length +
                                  (_hasMoreProducts ? 1 : 0),
                              separatorBuilder: (context, index) => Divider(
                                  height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                if (index == _filteredProducts.length) {
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

                                final product = _filteredProducts[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.productName,
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

                      // Warning when all quantities are zero
                      if (_productQuantities.values
                          .every((qty) => qty == 0)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If all products have zero quantities. Please add a comment.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: _productQuantities.values
                                  .every((qty) => qty == 0)
                              ? 'Comment (Required when all quantities are zero)'
                              : 'Comment (Optional)',
                          hintText: _productQuantities.values
                                  .every((qty) => qty == 0)
                              ? 'Please explain why all products have zero quantities...'
                              : 'Add notes about product availability or any issues...',
                          border: const OutlineInputBorder(),
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
