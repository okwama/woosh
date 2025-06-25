import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:glamour_queen/models/hive/order_model.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/models/product_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/paginated_service.dart';
import 'package:glamour_queen/utils/pagination_utils.dart';
import 'package:glamour_queen/pages/order/product/product_detail_page.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/utils/image_utils.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/skeleton_loader.dart';
import 'package:glamour_queen/services/hive/product_hive_service.dart';
import 'package:glamour_queen/models/hive/product_model.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:get_storage/get_storage.dart';

class ProductsGridPage extends StatefulWidget {
  final Outlet outlet;
  final OrderModel? order;

  const ProductsGridPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  _ProductsGridPageState createState() => _ProductsGridPageState();
}

class _ProductsGridPageState extends State<ProductsGridPage>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  late PaginatedService<Product> _productService;
  PaginatedData<Product>? _paginatedData;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _currentSearchQuery = '';
  late ProductHiveService _productHiveService;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _productService = PaginatedService<Product>(
      fetchData: ({int? page, int? limit, String? search}) =>
          ApiService.getProducts(
        page: page ?? 1,
        limit: limit ?? 20,
        search: search,
        clientId: widget.outlet.id,
      ),
      pageSize: 20,
    );
    _initializeAndLoad();
    _scrollController.addListener(_onScroll);
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasConnected = _isConnected;
      _isConnected = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);

      if (!wasConnected && _isConnected) {
        // Reconnected - refresh data if we have stale data
        _refreshData();
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    try {
      ensureProductHiveAdapterRegistered();

      if (Get.isRegistered<ProductHiveService>()) {
        _productHiveService = Get.find<ProductHiveService>();
        debugPrint('[ProductsGrid] Found ProductHiveService from Get');
      } else {
        _productHiveService = ProductHiveService();
        await _productHiveService.init();
        Get.put(_productHiveService);
        debugPrint('[ProductsGrid] Created new ProductHiveService instance');
      }

      await _loadFromCacheAndApi();
    } catch (e) {
      debugPrint('[ProductsGrid] Error initializing: $e');
      _loadInitialData();
    }
  }

  // Calculate responsive grid parameters
  Map<String, dynamic> _getGridParameters(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    double childAspectRatio;
    double spacing;

    if (screenWidth < mobileBreakpoint) {
      // Mobile: 2 columns
      crossAxisCount = 2;
      childAspectRatio = 0.75;
      spacing = 8.0;
    } else if (screenWidth < tabletBreakpoint) {
      // Tablet: 3 columns
      crossAxisCount = 3;
      childAspectRatio = 0.8;
      spacing = 12.0;
    } else {
      // Desktop: 4+ columns
      crossAxisCount = (screenWidth / 250).floor().clamp(4, 6);
      childAspectRatio = 0.85;
      spacing = 16.0;
    }

    return {
      'crossAxisCount': crossAxisCount,
      'childAspectRatio': childAspectRatio,
      'spacing': spacing,
    };
  }

  List<Product> _getFilteredProducts() {
    if (_paginatedData == null) return [];
    final query = _currentSearchQuery.toLowerCase();
    if (query.isEmpty) return _paginatedData!.items;
    return _paginatedData!.items.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_currentSearchQuery != query) {
        setState(() {
          _currentSearchQuery = query;
        });
        if (query.length >= 2 || query.isEmpty) {
          _productService.updateSearch(query);
          _loadInitialData();
        }
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await _loadInitialData();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadFromCacheAndApi() async {
    await _loadFromCache();

    final connectivityResult = await Connectivity().checkConnectivity();
    _isConnected = connectivityResult != ConnectivityResult.none;

    if (_isConnected) {
      await _loadInitialData();
    } else if (_paginatedData == null || _paginatedData!.items.isEmpty) {
      setState(() {
        _error = 'No internet connection. Please check your network settings.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFromCache() async {
    if (_paginatedData == null) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final cachedProducts = await _productHiveService.getAllProducts();
      if (cachedProducts.isNotEmpty && mounted) {
        debugPrint(
            '[ProductsGrid] Loaded ${cachedProducts.length} products from cache');

        setState(() {
          _paginatedData = PaginatedData<Product>(
            items: cachedProducts,
            currentPage: 1,
            totalPages: 1,
            hasMore: false,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProductsGrid] Error loading products from cache: $e');
    }
  }

  Future<void> _loadInitialData() async {
    if (!_isConnected &&
        _paginatedData != null &&
        _paginatedData!.items.isNotEmpty) {
      return; // Don't load if offline and we have cached data
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _productService.loadInitialData();

      if (mounted) {
        setState(() {
          _paginatedData = data;
          _isLoading = false;
        });

        // Save to cache in background
        _saveToCache(data.items);
      }
    } catch (e) {
      debugPrint('[ProductsGrid] Error loading products from API: $e');
      if (mounted) {
        setState(() {
          _error = _isConnected
              ? 'Failed to load products. Please try again.'
              : 'No internet connection. Showing cached data.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToCache(List<Product> products) async {
    try {
      if (Get.isRegistered<ProductHiveService>()) {
        await _productHiveService.saveProducts(products);
        await _productHiveService.setLastUpdateTime(DateTime.now());
        debugPrint('[ProductsGrid] Saved ${products.length} products to cache');
      }
    } catch (e) {
      debugPrint('[ProductsGrid] Error saving to cache: $e');
    }
  }

  Future<void> _loadMoreData() async {
    if (_paginatedData == null ||
        !_paginatedData!.hasMore ||
        _isLoading ||
        !_isConnected) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final newData = await _productService.loadMoreData(_paginatedData!);

      if (mounted) {
        setState(() {
          _paginatedData = newData;
          _isLoading = false;
        });

        // Save new items to cache
        final previousCount = _paginatedData!.items.length;
        final newProducts = newData.items.sublist(previousCount);
        _saveToCache(newProducts);
      }
    } catch (e) {
      debugPrint('[ProductsGrid] Error loading more products: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load more products';
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreData();
    }
  }

  Widget _buildProductCard(Product product, int index, double spacing) {
    final userData = GetStorage().read('salesRep');
    final regionId = userData?['region_id'];
    final availableStock =
        regionId != null ? product.getMaxQuantityInRegion(regionId) : 0;
    final isOutOfStock = availableStock <= 0;

    return Card(
      key: ValueKey('product_${product.id}_$index'),
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Get.to(
            () => ProductDetailPage(
              outlet: widget.outlet,
              product: product,
              order: widget.order,
            ),
            preventDuplicates: true,
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 300),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 13,
              child: Stack(
                children: [
                  Hero(
                    tag: 'product_image_${product.id}',
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: product.imageUrl?.isNotEmpty ?? false
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: CachedNetworkImage(
                                imageUrl:
                                    ImageUtils.getGridUrl(product.imageUrl!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[100],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 32,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Image not available',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 32,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No image',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  // Stock status badge with animation
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red.withOpacity(0.9)
                            : Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isOutOfStock ? Colors.red : Colors.green)
                                .withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of Stock' : 'In Stock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (product.priceOptions.isNotEmpty)
                          Expanded(
                            child: Text(
                              'Ksh ${product.priceOptions.first.value}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        if (!isOutOfStock)
                          Text(
                            'Stock: $availableStock',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(double spacing) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (_isConnected) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange[100],
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 8),
          Text(
            'You\'re offline. Showing cached data.',
            style: TextStyle(
              color: Colors.orange[800],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _currentSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredProducts = _getFilteredProducts();
    final bool isInitialLoading = _isLoading && _paginatedData == null;
    final gridParams = _getGridParameters(context);

    return FutureBuilder<DateTime?>(
      future: Get.isRegistered<ProductHiveService>()
          ? Get.find<ProductHiveService>().getLastUpdateTime()
          : Future.value(null),
      builder: (context, snapshot) {
        final DateTime? lastUpdate = snapshot.data;

        return Scaffold(
          backgroundColor: appBackground,
          appBar: GradientAppBar(
            title: widget.outlet.name,
            actions: [
              if (_isConnected)
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isRefreshing ? null : _refreshData,
                  tooltip: 'Refresh',
                ),
              if (lastUpdate != null)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Last updated: ${lastUpdate.toString().substring(0, 16)}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Last update info',
                ),
            ],
          ),
          body: Column(
            children: [
              _buildConnectionStatus(),
              if (!isInitialLoading) _buildSearchBar(),
              if (_error != null && !isInitialLoading)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: isInitialLoading
                    ? GridView.builder(
                        padding: EdgeInsets.all(gridParams['spacing']),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridParams['crossAxisCount'],
                          childAspectRatio: gridParams['childAspectRatio'],
                          crossAxisSpacing: gridParams['spacing'],
                          mainAxisSpacing: gridParams['spacing'],
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) =>
                            _buildSkeletonCard(gridParams['spacing']),
                      )
                    : filteredProducts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refreshData,
                            child: GridView.builder(
                              controller: _scrollController,
                              key: const PageStorageKey('products_grid'),
                              padding: EdgeInsets.all(gridParams['spacing']),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridParams['crossAxisCount'],
                                childAspectRatio:
                                    gridParams['childAspectRatio'],
                                crossAxisSpacing: gridParams['spacing'],
                                mainAxisSpacing: gridParams['spacing'],
                              ),
                              itemCount: filteredProducts.length +
                                  (_paginatedData?.hasMore ?? false ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filteredProducts.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  );
                                }
                                return _buildProductCard(
                                  filteredProducts[index],
                                  index,
                                  gridParams['spacing'],
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentSearchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _currentSearchQuery.isNotEmpty
                ? 'No products found'
                : 'No products available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentSearchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Products will appear here when available',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_currentSearchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _productService.dispose();
    _searchDebounce?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
