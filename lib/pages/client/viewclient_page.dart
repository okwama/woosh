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
import 'package:woosh/pages/journeyplan/reports/pages/product_return_page.dart';
import '../../services/hive/client_hive_service.dart';
import '../../models/hive/client_model.dart';


class ViewClientPage extends StatefulWidget {
  final bool forOrderCreation;
  final bool forUpliftSale;
  final bool forProductReturn;

  const ViewClientPage({
    super.key,
    this.forOrderCreation = false,
    this.forUpliftSale = false,
    this.forProductReturn = false,
  });

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
  static const int _pageSize = 2000; // Smaller page size for better performance
  static const int _prefetchThreshold =
      2000; // Increased threshold to load earlier when scrolling

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
    // Debug print to verify scroll events
    print('Scroll position: ${_scrollController.position.pixels}, Max: ${_scrollController.position.maxScrollExtent}');
    
    // Check if we're near the bottom of the list
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - _prefetchThreshold &&
        !_isLoadingMore &&
        _hasMore) {
      print('Triggering load more at page: ${_currentPage + 1}');
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
      // First try to load from local cache
      final clientHiveService = Get.find<ClientHiveService>();
      final cachedClients = clientHiveService.getAllClients();
      
      if (cachedClients.isNotEmpty) {
        // Convert ClientModel to Outlet
        final cachedOutlets = cachedClients.map((client) => Outlet(
              id: client.id,
              name: client.name,
              address: client.address,
              latitude: client.latitude,
              longitude: client.longitude,
              email: client.email,
              contact: client.phone, // Use phone as contact
              regionId: 0, // Default values for required fields
              region: '', // Default values for required fields
              countryId: 0, // Default values for required fields
            )).toList();
        
        setState(() {
          _outlets = cachedOutlets;
          _isLoading = false;
        });
      }
      
      // Then try to fetch from API (even if we loaded from cache)
      try {
        final routeId = ApiService.getCurrentUserRouteId();
        final outlets = await ApiService.fetchOutlets(
          page: 1,
          limit: _pageSize,
          routeId: routeId,
        );
        
        // Save to local cache
        final clientModels = outlets.map((outlet) => ClientModel(
              id: outlet.id,
              name: outlet.name,
              address: outlet.address,
              phone: outlet.contact ?? '', // Use contact as phone
              email: outlet.email ?? '',
              latitude: outlet.latitude ?? 0.0,
              longitude: outlet.longitude ?? 0.0,
              status: 'active', // Default status
            )).toList();
        
        await clientHiveService.saveClients(clientModels);
        
        setState(() {
          _outlets = outlets;
          _isLoading = false;
          _hasMore = outlets.length >= _pageSize;
        });
      } catch (e) {
        // If we already loaded from cache, just show a toast
        if (cachedClients.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Using cached data. Could not refresh from server.')),
          );
          setState(() {
            _isLoading = false;
          });
        } else {
          // If we don't have cached data, show error
          setState(() {
            _errorMessage =
                'Unable to connect to the server. Please check your internet connection and try again.';
            _isLoading = false;
          });
          _showErrorDialog();
        }
      }
    } catch (e) {
      // Error with Hive or other unexpected error
      setState(() {
        _errorMessage =
            'An unexpected error occurred. Please try again.';
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
      final routeId = ApiService.getCurrentUserRouteId();
      final newOutlets = await ApiService.fetchOutlets(
        page: _currentPage + 1,
        limit: _pageSize,
        routeId: routeId,
      );

      if (mounted) {
        // Save to local cache
        final clientHiveService = Get.find<ClientHiveService>();
        final clientModels = newOutlets.map((outlet) => ClientModel(
              id: outlet.id,
              name: outlet.name,
              address: outlet.address,
              phone: outlet.contact ?? '', // Use contact as phone
              email: outlet.email ?? '',
              latitude: outlet.latitude ?? 0.0,
              longitude: outlet.longitude ?? 0.0,
              status: 'active', // Default status
            )).toList();
        
        await clientHiveService.saveClients(clientModels);
        
        setState(() {
          _outlets.addAll(newOutlets);
          _currentPage++;
          _isLoadingMore = false;
          // Make sure we only set hasMore to false if we received fewer items than requested
          _hasMore = newOutlets.length >= _pageSize;
          print('Loaded ${newOutlets.length} more outlets, hasMore: $_hasMore');
        });
      }
    } catch (e) {
      print('Error loading more outlets: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load more outlets. Check your connection.')),
        );
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
    } else if (widget.forProductReturn) {
      Get.to(
        () => ProductReturnPage(outlet: outlet),
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

  // Helper method to build the list footer
  Widget _buildListFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('No more outlets to load')),
      );
    }
    return const SizedBox(height: 80); // Add space at the bottom for better UX
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
                                  return _buildListFooter();
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
              builder: (context) => AddClientPage(),
            ),
          ).then((_) => _loadOutlets()); // Refresh list after returning
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class ClientController extends GetxController {
  final ClientHiveService _hiveService = ClientHiveService();
  final _clients = <ClientModel>[].obs;
  final _isLoading = false.obs;
  final _searchQuery = ''.obs;

  List<ClientModel> get clients => _searchQuery.isEmpty
      ? _clients
      : _hiveService.searchClients(_searchQuery.value);
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadClients();
  }

  Future<void> loadClients() async {
    _isLoading.value = true;
    try {
      // First load from Hive
      final localClients = _hiveService.getAllClients();
      if (localClients.isNotEmpty) {
        _clients.value = localClients;
      }

      // Then fetch from API and update Hive
      final apiClients = await ApiService.getClients();
      final clientModels =
          apiClients.map((client) => ClientModel.fromJson(client as Map<String, dynamic>)).toList();

      await _hiveService.saveClients(clientModels);
      _clients.value = clientModels;
    } catch (e) {
      print('Error loading clients: $e');
      // If API call fails, we still have the local data
    } finally {
      _isLoading.value = false;
    }
  }

  void searchClients(String query) {
    _searchQuery.value = query;
  }

  Future<void> refreshClients() async {
    await loadClients();
  }
}
