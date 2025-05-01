// View Client Page
import 'package:flutter/material.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:woosh/pages/client/addclient_page.dart';
import 'package:woosh/pages/client/clientdetails.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';
import 'package:get/get.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/pages/pos/upliftSaleCart_page.dart';

class ViewClientPage extends StatefulWidget {
  final bool forOrderCreation;
  final bool forUpliftSale;

  const ViewClientPage({
    Key? key,
    this.forOrderCreation = false,
    this.forUpliftSale = false,
  }) : super(key: key);

  @override
  State<ViewClientPage> createState() => _ViewClientPageState();
}

class _ViewClientPageState extends State<ViewClientPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Outlet> _outlets = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;
  static const int _prefetchThreshold =
      200; // Start loading 200px before bottom

  @override
  void initState() {
    super.initState();
    _loadOutlets();
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
      _loadMoreOutlets();
    }
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      // Clear cache when refreshing
      ApiService.clearOutletsCache();

      final outlets = await ApiService.fetchOutlets(page: 1, limit: _pageSize);
      setState(() {
        _outlets = outlets;
        _isLoading = false;
        _hasMore = outlets.length >= _pageSize;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Unable to connect to the server. Please check your internet connection and try again.';
        _isLoading = false;
      });
      _showErrorDialog();
    }
  }

  Future<void> _loadMoreOutlets() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newOutlets = await ApiService.fetchOutlets(
        page: _currentPage + 1,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _outlets.addAll(newOutlets);
          _currentPage++;
          _isLoadingMore = false;
          _hasMore = newOutlets.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unable to load outlets. This could be due to:'),
              const SizedBox(height: 8),
              Text('• No internet connection'),
              Text('• Server is temporarily unavailable'),
              Text('• Database connection issues'),
              const SizedBox(height: 16),
              const Text('Would you like to retry?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadOutlets();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  List<Outlet> _getFilteredOutlets() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _outlets;
    return _outlets.where((outlet) {
      return outlet.name.toLowerCase().contains(query) ||
          outlet.address.toLowerCase().contains(query);
    }).toList();
  }

  void _onClientSelected(Outlet outlet) {
    if (widget.forOrderCreation) {
      Get.to(
        () => AddOrderPage(outlet: outlet),
        transition: Transition.rightToLeft,
      );
    } else if (widget.forUpliftSale) {
      Get.off(
        () => UpliftSaleCartPage(
          outlet: outlet,
        ),
        transition: Transition.rightToLeft,
      );
    } else {
      // Show client details
      Get.to(
        () => ClientDetailsPage(outlet: outlet),
        transition: Transition.rightToLeft,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'View Clients',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOutlets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search outlets...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Outlets List
          Expanded(
            child: _isLoading
                ? const ClientListSkeleton()
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadOutlets,
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
                    : _getFilteredOutlets().isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No outlets found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty) ...[
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
                        : RefreshIndicator(
                            onRefresh: _loadOutlets,
                            child: ListView.builder(
                              key: const PageStorageKey('outlets_list'),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _getFilteredOutlets().length +
                                  (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _getFilteredOutlets().length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }

                                final outlet = _getFilteredOutlets()[index];
                                return Card(
                                  key: ValueKey('outlet_${outlet.id}_$index'),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _onClientSelected(outlet),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.store,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      outlet.name,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      outlet.address,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddClientPage(),
            ),
          ).then((_) => _loadOutlets()); // Refresh list after returning
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
