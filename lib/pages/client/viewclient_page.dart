import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:glamour_queen/models/hive/client_model.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/pages/order/addorder_page.dart';
import 'package:glamour_queen/pages/client/addclient_page.dart';
import 'package:glamour_queen/pages/client/clientdetails.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/skeleton_loader.dart';
import 'package:glamour_queen/models/client_model.dart';
import 'package:glamour_queen/pages/pos/upliftSaleCart_page.dart';
import 'package:glamour_queen/pages/journeyplan/reports/pages/product_return_page.dart';
import 'package:glamour_queen/services/hive/client_hive_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:get_storage/get_storage.dart';

enum SortOption { nameAsc, nameDesc, addressAsc, addressDesc }

enum DateFilter { all, today, thisWeek, thisMonth }

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
  bool _isSearching = false;
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Filter options
  SortOption _sortOption = SortOption.nameAsc;
  bool _showFilters = false;
  bool _showOnlyWithContact = false;
  bool _showOnlyWithEmail = false;
  DateFilter _dateFilter = DateFilter.all;

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
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
      if (_isOnline && _outlets.isEmpty) {
        _loadOutlets();
      }
    });

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
    setState(() {
      _isSearching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          // If we have a search query and we haven't loaded all pages yet,
          // load more pages until we find the result or reach the end
          if (query.isNotEmpty && _hasMore) {
            _loadMoreUntilFound(query);
          }
          _isSearching = false;
        });
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
      print('?? Loaded ${_outlets.length} clients from cache');

      // Then fetch from API
      final routeId = ApiService.getCurrentUserRouteId();
      print('?? Route ID: $routeId');

      // Debug: Check what's in salesRep data
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      print('?? SalesRep data: $salesRep');

      print('?? Fetching page 1 with limit $_pageSize');

      // Use the newer fetchClients method instead of deprecated fetchOutlets
      // Make route filtering optional - only filter if routeId is not null
      final paginatedResponse = await ApiService.fetchClients(
        routeId: null, // Temporarily disable route filtering to get all clients
        page: 1,
        limit: _pageSize,
      );
      final outlets = paginatedResponse.data
          .map((client) => Outlet(
                id: client.id,
                name: client.name,
                address: client.address,
                latitude: client.latitude,
                longitude: client.longitude,
                email: '',
                contact: '',
                regionId: client.regionId,
                region: client.region,
                countryId: client.countryId,
              ))
          .toList();

      print('? Fetched ${outlets.length} clients from API');

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
      print('?? Saved ${clientModels.length} clients to cache');

      if (mounted) {
        setState(() {
          _outlets = outlets;
          _isLoading = false;
          _hasMore = outlets.length >= _pageSize;
        });
        print('?? Total clients loaded: ${_outlets.length}');
        print('?? Has more clients: $_hasMore');
      }
    } catch (e) {
      print('? Error loading clients: $e');
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
      print('?? Found ${cachedClients.length} clients in cache');

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
          print('?? Loaded ${cachedOutlets.length} clients from cache');
        }
      }
    } catch (e) {
      print('? Error loading from cache: $e');
    }
  }

  Future<void> _loadMoreOutlets() async {
    if (!_isOnline || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final routeId = ApiService.getCurrentUserRouteId();
      print('?? Route ID: $routeId');
      print('?? Fetching page ${_currentPage + 1} with limit $_pageSize');

      // Use the newer fetchClients method instead of deprecated fetchOutlets
      // Make route filtering optional - only filter if routeId is not null
      final paginatedResponse = await ApiService.fetchClients(
        routeId: null, // Temporarily disable route filtering to get all clients
        page: _currentPage + 1,
        limit: _pageSize,
      );
      final newOutlets = paginatedResponse.data
          .map((client) => Outlet(
                id: client.id,
                name: client.name,
                address: client.address,
                latitude: client.latitude,
                longitude: client.longitude,
                email: '',
                contact: '',
                regionId: client.regionId,
                region: client.region,
                countryId: client.countryId,
              ))
          .toList();

      print('? Fetched ${newOutlets.length} more clients from API');

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
      print('?? Saved ${clientModels.length} more clients to cache');

      if (mounted) {
        setState(() {
          _outlets.addAll(newOutlets);
          _currentPage++;
          _isLoadingMore = false;
          _hasMore = newOutlets.length >= _pageSize;
        });
        print('?? Total clients after loading more: ${_outlets.length}');
        print('?? Has more clients: $_hasMore');
      }
    } catch (e) {
      print('? Error loading more clients: $e');
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

  Future<void> _loadMoreUntilFound(String query) async {
    if (!_isOnline || _isLoadingMore) return;

    final searchTerms = query.toLowerCase().split(' ');
    bool foundMatch = _outlets.any((outlet) {
      final name = outlet.name.toLowerCase();
      final address = outlet.address.toLowerCase();
      final contact = outlet.contact?.toLowerCase() ?? '';
      final email = outlet.email?.toLowerCase() ?? '';

      return searchTerms.every((term) =>
          name.contains(term) ||
          address.contains(term) ||
          contact.contains(term) ||
          email.contains(term));
    });

    // If we haven't found a match and there are more pages, load the next page
    while (!foundMatch && _hasMore) {
      await _loadMoreOutlets();

      foundMatch = _outlets.any((outlet) {
        final name = outlet.name.toLowerCase();
        final address = outlet.address.toLowerCase();
        final contact = outlet.contact?.toLowerCase() ?? '';
        final email = outlet.email?.toLowerCase() ?? '';

        return searchTerms.every((term) =>
            name.contains(term) ||
            address.contains(term) ||
            contact.contains(term) ||
            email.contains(term));
      });
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
    List<Outlet> filtered = _outlets;

    // Apply text search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((outlet) {
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

    // Apply contact filter
    if (_showOnlyWithContact) {
      filtered = filtered
          .where((outlet) => outlet.contact?.isNotEmpty == true)
          .toList();
    }

    // Apply email filter
    if (_showOnlyWithEmail) {
      filtered =
          filtered.where((outlet) => outlet.email?.isNotEmpty == true).toList();
    }

    // Apply date filter
    if (_dateFilter != DateFilter.all) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      filtered = filtered.where((outlet) {
        final outletDate = outlet.createdAt;
        if (outletDate == null) return false;

        switch (_dateFilter) {
          case DateFilter.today:
            return outletDate.isAfter(today);
          case DateFilter.thisWeek:
            return outletDate.isAfter(startOfWeek);
          case DateFilter.thisMonth:
            return outletDate.isAfter(startOfMonth);
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.addressAsc:
        filtered.sort((a, b) => a.address.compareTo(b.address));
        break;
      case SortOption.addressDesc:
        filtered.sort((a, b) => b.address.compareTo(a.address));
        break;
    }

    return filtered;
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
                ? 'No Clients Assigned to this user'
                : 'Try a different search term',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 16),
            // ElevatedButton.icon(
            //   onPressed: () => Get.to(() => const AddClientPage()),
            //   icon: const Icon(Icons.add),
            //   label: const Text('Add Client'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Theme.of(context).primaryColor,
            //     foregroundColor: Colors.white,
            //   ),
            // ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    if (!_showFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sort by:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButton<SortOption>(
                      value: _sortOption,
                      isExpanded: true,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(
                            value: SortOption.nameAsc,
                            child: Text('Name (A-Z)')),
                        DropdownMenuItem(
                            value: SortOption.nameDesc,
                            child: Text('Name (Z-A)')),
                        DropdownMenuItem(
                            value: SortOption.addressAsc,
                            child: Text('Address (A-Z)')),
                        DropdownMenuItem(
                            value: SortOption.addressDesc,
                            child: Text('Address (Z-A)')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortOption = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date Range:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButton<DateFilter>(
                      value: _dateFilter,
                      isExpanded: true,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(
                            value: DateFilter.all, child: Text('All Time')),
                        DropdownMenuItem(
                            value: DateFilter.today, child: Text('Today')),
                        DropdownMenuItem(
                            value: DateFilter.thisWeek,
                            child: Text('This Week')),
                        DropdownMenuItem(
                            value: DateFilter.thisMonth,
                            child: Text('This Month')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _dateFilter = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              FilterChip(
                label:
                    const Text('Has Contact', style: TextStyle(fontSize: 11)),
                selected: _showOnlyWithContact,
                onSelected: (value) {
                  setState(() {
                    _showOnlyWithContact = value;
                  });
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Has Email', style: TextStyle(fontSize: 11)),
                selected: _showOnlyWithEmail,
                onSelected: (value) {
                  setState(() {
                    _showOnlyWithEmail = value;
                  });
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filteredOutlets.length;
    final totalCount = _outlets.length;

    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Clients ($totalCount)',
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadOutlets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Stack(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: _onSearchChanged,
                ),
                if (_isSearching)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Filter Panel
          _buildFilterPanel(),
          if (_showFilters) const SizedBox(height: 6),
          // Results count and network status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                if (filteredCount != totalCount)
                  Text(
                    'Showing $filteredCount of $totalCount clients',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                if (!_isOnline)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Offline',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ),
              ],
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
                              size: 36,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadOutlets,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                                  margin: const EdgeInsets.only(bottom: 6),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _onClientSelected(outlet),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
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
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  outlet.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  outlet.address,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (outlet
                                                        .contact?.isNotEmpty ??
                                                    false) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.phone,
                                                        size: 10,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        outlet.contact!,
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                if (outlet.email?.isNotEmpty ??
                                                    false) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.email,
                                                        size: 10,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          outlet.email!,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey.shade600,
                                                            fontSize: 11,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey.shade400,
                                            size: 18,
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
              print('?? Refreshing after adding new client');
              final outlets = await ApiService.fetchOutlets(
                page: 1,
                limit: _pageSize,
                routeId: routeId,
              );
              print('? Refreshed ${outlets.length} clients');

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
              print('?? Updated cache with ${clientModels.length} clients');

              if (mounted) {
                setState(() {
                  _outlets = outlets;
                  _isLoading = false;
                  _hasMore = outlets.length >= _pageSize;
                });
                print('?? Total clients after refresh: ${_outlets.length}');
              }
            } catch (e) {
              print('? Error refreshing after adding client: $e');
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
