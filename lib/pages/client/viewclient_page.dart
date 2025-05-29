import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/hive/client_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:woosh/pages/client/addclient_page.dart';
import 'package:woosh/pages/client/clientdetails.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/pages/pos/upliftSaleCart_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_return_page.dart';
import 'package:woosh/services/hive/client_hive_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

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
  bool _isOnline = true;
  List<Outlet> _outlets = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 2000;
  static const int _prefetchThreshold = 200;
  Timer? _debounce;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadOutlets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    _connectivitySubscription = Connectivity()
            .onConnectivityChanged
            .listen((ConnectivityResult result) {
              setState(() {
                _isOnline = result != ConnectivityResult.none;
              });
              if (_isOnline && _outlets.isEmpty) {
                _loadOutlets();
              }
            } as void Function(List<ConnectivityResult> event)?)
        as StreamSubscription<ConnectivityResult>?;

    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - _prefetchThreshold &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreOutlets();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadOutlets() async {
    if (!_isOnline) {
      _loadFromCache();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      // First load from cache for quick display
      await _loadFromCache();
      print('📱 Loaded ${_outlets.length} clients from cache');

      // Then fetch from API
      final routeId = ApiService.getCurrentUserRouteId();
      print('🌐 Fetching page 1 with limit $_pageSize');
      final outlets = await ApiService.fetchOutlets(
        page: 1,
        limit: _pageSize,
        routeId: routeId,
      );
      print('✅ Fetched ${outlets.length} clients from API');

      // Save to local cache
      final clientHiveService = Get.find<ClientHiveService>();
      final clientModels = outlets
          .map((outlet) => ClientModel(
                id: outlet.id,
                name: outlet.name,
                address: outlet.address,
                phone: outlet.contact ?? '',
                email: outlet.email ?? '',
                latitude: outlet.latitude ?? 0.0,
                longitude: outlet.longitude ?? 0.0,
                status: 'active',
              ))
          .toList();

      await clientHiveService.saveClients(clientModels);
      print('💾 Saved ${clientModels.length} clients to cache');

      if (mounted) {
        setState(() {
          _outlets = outlets;
          _isLoading = false;
          _hasMore = outlets.length >= _pageSize;
        });
        print('📊 Total clients loaded: ${_outlets.length}');
        print('🔄 Has more clients: $_hasMore');
      }
    } catch (e) {
      print('❌ Error loading clients: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to load clients. ${_outlets.isEmpty ? 'No cached data available.' : 'Showing cached data.'}';
          _isLoading = false;
        });

        if (_outlets.isEmpty) {
          _showErrorDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final clientHiveService = Get.find<ClientHiveService>();
      final cachedClients = clientHiveService.getAllClients();
      print('📱 Found ${cachedClients.length} clients in cache');

      if (cachedClients.isNotEmpty) {
        final cachedOutlets = cachedClients
            .map((client) => Outlet(
                  id: client.id,
                  name: client.name,
                  address: client.address,
                  latitude: client.latitude,
                  longitude: client.longitude,
                  email: client.email,
                  contact: client.phone,
                  regionId: 0,
                  region: '',
                  countryId: 0,
                ))
            .toList();

        if (mounted) {
          setState(() {
            _outlets = cachedOutlets;
          });
          print('📊 Loaded ${cachedOutlets.length} clients from cache');
        }
      }
    } catch (e) {
      print('❌ Error loading from cache: $e');
    }
  }

  Future<void> _loadMoreOutlets() async {
    if (!_isOnline || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final routeId = ApiService.getCurrentUserRouteId();
      print('🌐 Fetching page ${_currentPage + 1} with limit $_pageSize');
      final newOutlets = await ApiService.fetchOutlets(
        page: _currentPage + 1,
        limit: _pageSize,
        routeId: routeId,
      );
      print('✅ Fetched ${newOutlets.length} more clients from API');

      // Save to local cache
      final clientHiveService = Get.find<ClientHiveService>();
      final clientModels = newOutlets
          .map((outlet) => ClientModel(
                id: outlet.id,
                name: outlet.name,
                address: outlet.address,
                phone: outlet.contact ?? '',
                email: outlet.email ?? '',
                latitude: outlet.latitude ?? 0.0,
                longitude: outlet.longitude ?? 0.0,
                status: 'active',
              ))
          .toList();

      await clientHiveService.saveClients(clientModels);
      print('💾 Saved ${clientModels.length} more clients to cache');

      if (mounted) {
        setState(() {
          _outlets.addAll(newOutlets);
          _currentPage++;
          _isLoadingMore = false;
          _hasMore = newOutlets.length >= _pageSize;
        });
        print('📊 Total clients after loading more: ${_outlets.length}');
        print('🔄 Has more clients: $_hasMore');
      }
    } catch (e) {
      print('❌ Error loading more clients: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load more clients'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text(
            'Could not connect to the server. Please check your internet connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (_outlets.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadOutlets();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  List<Outlet> get _filteredOutlets {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _outlets;

    return _outlets.where((outlet) {
      final name = outlet.name.toLowerCase();
      final address = outlet.address.toLowerCase();
      final contact = outlet.contact?.toLowerCase() ?? '';
      final email = outlet.email?.toLowerCase() ?? '';

      final searchTerms = query.split(' ');
      return searchTerms.every((term) =>
          name.contains(term) ||
          address.contains(term) ||
          contact.contains(term) ||
          email.contains(term));
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
        () => UpliftSaleCartPage(outlet: outlet),
        transition: Transition.rightToLeft,
      );
    } else if (widget.forProductReturn) {
      Get.to(
        () => ProductReturnPage(outlet: outlet),
        transition: Transition.rightToLeft,
      );
    } else {
      Get.to(
        () => ClientDetailsPage(outlet: outlet),
        transition: Transition.rightToLeft,
      );
    }
  }

  Widget _buildListFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!_hasMore && _filteredOutlets.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('End of list')),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No clients found'
                : 'No matching clients',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Add a new client or check your connection'
                : 'Try a different search term',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Get.to(() => const AddClientPage()),
              icon: const Icon(Icons.add),
              label: const Text('Add Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
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
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Network status indicator
          if (!_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.orange.shade100,
              child: const Center(
                child: Text(
                  'Offline mode - showing cached data',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
          // Outlets List
          Expanded(
            child: _isLoading && _outlets.isEmpty
                ? const ClientListSkeleton()
                : _errorMessage != null && _outlets.isEmpty
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
                    : _filteredOutlets.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadOutlets,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _filteredOutlets.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _filteredOutlets.length) {
                                  return _buildListFooter();
                                }

                                final outlet = _filteredOutlets[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _onClientSelected(outlet),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.store,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  outlet.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  outlet.address,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (outlet
                                                        .contact?.isNotEmpty ??
                                                    false) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    outlet.contact!,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey.shade400,
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
        onPressed: () async {
          await Get.to(() => const AddClientPage());
          // Refresh only the first page after adding a new client
          if (mounted) {
            setState(() {
              _isLoading = true;
              _currentPage = 1;
              _hasMore = true;
            });

            try {
              final routeId = ApiService.getCurrentUserRouteId();
              print('🔄 Refreshing after adding new client');
              final outlets = await ApiService.fetchOutlets(
                page: 1,
                limit: _pageSize,
                routeId: routeId,
              );
              print('✅ Refreshed ${outlets.length} clients');

              // Save to local cache
              final clientHiveService = Get.find<ClientHiveService>();
              final clientModels = outlets
                  .map((outlet) => ClientModel(
                        id: outlet.id,
                        name: outlet.name,
                        address: outlet.address,
                        phone: outlet.contact ?? '',
                        email: outlet.email ?? '',
                        latitude: outlet.latitude ?? 0.0,
                        longitude: outlet.longitude ?? 0.0,
                        status: 'active',
                      ))
                  .toList();

              await clientHiveService.saveClients(clientModels);
              print('💾 Updated cache with ${clientModels.length} clients');

              if (mounted) {
                setState(() {
                  _outlets = outlets;
                  _isLoading = false;
                  _hasMore = outlets.length >= _pageSize;
                });
                print('📊 Total clients after refresh: ${_outlets.length}');
              }
            } catch (e) {
              print('❌ Error refreshing after adding client: $e');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to refresh client list'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
