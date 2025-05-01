import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/product/product_detail_page.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';

class ProductsGridPage extends StatefulWidget {
  final Outlet outlet;
  final Order? order;

  const ProductsGridPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  _ProductsGridPageState createState() => _ProductsGridPageState();
}

class _ProductsGridPageState extends State<ProductsGridPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;
  static const int _prefetchThreshold = 200;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - _prefetchThreshold &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final products = await _retryApiCall(
        () => ApiService.getProducts(page: 1, limit: _pageSize),
        maxRetries: 3,
        timeout: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _isLoading = false;
          _hasMore = products.length >= _pageSize;
        });
        _precacheProductImages(products);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Auto-refresh after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadProducts();
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newProducts = await _retryApiCall(
        () => ApiService.getProducts(
          page: _currentPage + 1,
          limit: _pageSize,
        ),
        maxRetries: 3,
        timeout: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _filteredProducts.addAll(newProducts);
          _currentPage++;
          _isLoadingMore = false;
          _hasMore = newProducts.length >= _pageSize;
        });
        _precacheProductImages(newProducts);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        // Auto-retry loading more after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadMoreProducts();
        });
      }
    }
  }

  Future<T> _retryApiCall<T>(
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await apiCall().timeout(timeout);
      } catch (e) {
        if (attempts >= maxRetries) {
          rethrow;
        }
        print('Retry attempt $attempts of $maxRetries after error: $e');
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }
  }

  void _precacheProductImages(List<Product> products) {
    if (Get.context == null) return;

    for (var product in products) {
      if (product.imageUrl?.isNotEmpty ?? false) {
        try {
          final imageUrl = ImageUtils.getGridUrl(product.imageUrl!);
          final imageProvider = NetworkImage(imageUrl);
          precacheImage(imageProvider, Get.context!);
        } catch (e) {
          print('Failed to precache image for product ${product.id}: $e');
          continue;
        }
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Widget _buildProductCard(Product product, int index) {
    return Card(
      key: ValueKey('product_${product.id}_$index'),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: product.imageUrl?.isNotEmpty ?? false
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getGridUrl(product.imageUrl!),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 32,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: widget.outlet.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _currentPage = 1;
                _hasMore = true;
                _products.clear();
                _filteredProducts.clear();
              });
              _loadProducts();
            },
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const ProductsGridSkeleton()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _filterProducts,
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: GridView.builder(
                      key: const PageStorageKey('products_grid'),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _filteredProducts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredProducts.length) {
                          return _isLoadingMore
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        return _buildProductCard(
                            _filteredProducts[index], index);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
