import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/paginated_service.dart';
import 'package:woosh/utils/pagination_utils.dart';
import 'package:woosh/pages/order/product/product_detail_page.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';
import 'dart:async';

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
  String? _error;
  late PaginatedService<Product> _productService;
  PaginatedData<Product>? _paginatedData;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _productService = PaginatedService<Product>(
      fetchData: ({int? page, int? limit, String? search}) =>
          ApiService.getProducts(
        page: page ?? 1,
        limit: limit ?? 20,
        search: search,
      ),
      pageSize: 20,
    );
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  List<Product> _getFilteredProducts() {
    if (_paginatedData == null) return [];
    final query = _currentSearchQuery.toLowerCase();
    if (query.isEmpty) return _paginatedData!.items;
    return _paginatedData!.items.where((product) {
      return product.name.toLowerCase().contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_currentSearchQuery != query) {
        setState(() {
          _currentSearchQuery = query;
        });
        _productService.updateSearch(query);
        _loadInitialData();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('[ProductsGrid] Loading initial products...');
      final data = await _productService.loadInitialData();

      if (mounted) {
        setState(() {
          _paginatedData = data;
          _isLoading = false;
          print('[ProductsGrid] Loaded ${data.items.length} products');
        });
      }
    } catch (e) {
      print('[ProductsGrid] Error loading products: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_paginatedData == null || !_paginatedData!.hasMore || _isLoading) {
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
          print(
              '[ProductsGrid] Loaded more products. Total: ${newData.items.length}');
        });
      }
    } catch (e) {
      print('[ProductsGrid] Error loading more products: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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

  Widget _buildSkeletonCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: widget.outlet.name,
      ),
      body: _isLoading && _paginatedData == null
          ? GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 6, // Show 6 skeleton cards while loading
              itemBuilder: (context, index) => _buildSkeletonCard(),
            )
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              if (_currentSearchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          key: const PageStorageKey('products_grid'),
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: filteredProducts.length +
                              (_paginatedData?.hasMore ?? false ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredProducts.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _buildProductCard(
                                filteredProducts[index], index);
                          },
                        ),
                ),
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
    super.dispose();
  }
}
