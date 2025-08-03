import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:woosh/services/client/index.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:woosh/pages/client/addclient_page.dart';
import 'package:woosh/pages/client/clientdetails.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/skeleton_loader.dart';
import 'package:woosh/pages/pos/uplift_sale_cart_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_return_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:woosh/models/hive/client_model.dart';
import 'package:woosh/models/clients/outlet_model.dart';

enum SortOption { nameAsc, nameDesc, contactAsc, contactDesc }

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
  bool _isSearching = false;
  bool _isOnline = true;
  List<Client> _clients = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Filter options
  SortOption _sortOption = SortOption.nameAsc;
  bool _showFilters = false;
  bool _showOnlyWithContact = false;
  bool _showOnlyWithEmail = false;
  DateFilter _dateFilter = DateFilter.all;

  // Client state service
  late final ClientStateService _clientStateService;

  @override
  void initState() {
    super.initState();
    _clientStateService = Get.find<ClientStateService>();
    _initConnectivity();
    _loadClients();
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
      setState(() {
        _isOnline = results.isNotEmpty &&
            results.any((result) => result != ConnectivityResult.none);
      });
      if (_isOnline && _clients.isEmpty) {
        _loadClients();
      }
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_clientStateService.isLoading.value &&
        _clientStateService.hasMoreData.value) {
      _loadMoreClients();
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
          _isSearching = false;
        });
        _searchClients(query);
      }
    });
  }

  Future<void> _loadClients() async {
    if (!_isOnline) {
      _loadFromCache();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load from cache first for quick display
      await _loadFromCache();

      // Fetch from API using basic fields for better performance
      await _clientStateService.fetchClientsBasic(refresh: true);

      if (mounted) {
        setState(() {
          _clients = _clientStateService.clients;
          _isLoading = false;
        });
        print('?? Loaded ${_clients.length} clients');
      }
    } catch (e) {
      print('? Error loading clients: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to load clients. ${_clients.isEmpty ? 'No cached data available.' : 'Showing cached data.'}';
          _isLoading = false;
        });

        if (_clients.isEmpty) {
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
      final cachedClients = ClientCacheService.getCachedClients();
      if (cachedClients.isNotEmpty) {
        setState(() {
          _clients = cachedClients;
        });
        print('?? Loaded ${cachedClients.length} clients from cache');
      }
    } catch (e) {
      print('? Error loading from cache: $e');
    }
  }

  Future<void> _loadMoreClients() async {
    if (!_isOnline || _clientStateService.isLoading.value) return;

    try {
      await _clientStateService.loadMoreClients();
      if (mounted) {
        setState(() {
          _clients = _clientStateService.clients;
        });
      }
    } catch (e) {
      print('? Error loading more clients: $e');
    }
  }

  Future<void> _searchClients(String query) async {
    if (query.isEmpty) {
      await _loadClients();
      return;
    }

    try {
      await _clientStateService.searchClientsBasic(query: query);
      if (mounted) {
        setState(() {
          _clients = _clientStateService.clients;
        });
      }
    } catch (e) {
      print('? Error searching clients: $e');
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
          if (_clients.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadClients();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  List<Client> get _filteredClients {
    final query = _searchController.text.toLowerCase().trim();
    List<Client> filtered = _clients;

    // Apply text search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((client) {
        final name = client.name.toLowerCase();
        final address = client.address?.toLowerCase() ?? '';
        final contact = client.contact.toLowerCase();
        final email = client.email?.toLowerCase() ?? '';

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
      filtered = filtered.where((client) => client.contact.isNotEmpty).toList();
    }

    // Apply email filter
    if (_showOnlyWithEmail) {
      filtered =
          filtered.where((client) => client.email?.isNotEmpty == true).toList();
    }

    // Apply date filter
    if (_dateFilter != DateFilter.all) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      filtered = filtered.where((client) {
        final clientDate = client.createdAt;
        if (clientDate == null) return false;

        switch (_dateFilter) {
          case DateFilter.today:
            return clientDate.isAfter(today);
          case DateFilter.thisWeek:
            return clientDate.isAfter(startOfWeek);
          case DateFilter.thisMonth:
            return clientDate.isAfter(startOfMonth);
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
      case SortOption.contactAsc:
        filtered.sort((a, b) => a.contact.compareTo(b.contact));
        break;
      case SortOption.contactDesc:
        filtered.sort((a, b) => b.contact.compareTo(a.contact));
        break;
    }

    return filtered;
  }

  void _onClientSelected(Client client) {
    if (widget.forOrderCreation) {
      Get.to(
        () => AddOrderPage(outlet: _convertClientToOutlet(client)),
        transition: Transition.rightToLeft,
      );
    } else if (widget.forUpliftSale) {
      Get.off(
        () => UpliftSaleCartPage(
            outlet: _convertClientToOutlet(client), client: client),
        transition: Transition.rightToLeft,
      );
    } else if (widget.forProductReturn) {
      Get.to(
        () => ProductReturnPage(client: _convertClientToClientModel(client)),
        transition: Transition.rightToLeft,
      );
    } else {
      Get.to(
        () => ClientDetailsPage(
            client: client, outlet: _convertClientToOutlet(client)),
        transition: Transition.rightToLeft,
      );
    }
  }

  // Convert Client to Outlet for compatibility with existing pages
  Outlet _convertClientToOutlet(Client client) {
    return Outlet.fromClient(client);
  }

  // Convert Client to ClientModel for ProductReturnPage
  ClientModel _convertClientToClientModel(Client client) {
    return ClientModel(
      id: client.id,
      name: client.name,
      address: client.address ?? '',
      phone: client.contact,
      email: client.email ?? '',
      latitude: client.latitude ?? 0.0,
      longitude: client.longitude ?? 0.0,
      status: 'active',
    );
  }

  Widget _buildListFooter() {
    if (_clientStateService.isLoading.value) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!_clientStateService.hasMoreData.value &&
        _filteredClients.isNotEmpty) {
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
                            value: SortOption.contactAsc,
                            child: Text('Contact (A-Z)')),
                        DropdownMenuItem(
                            value: SortOption.contactDesc,
                            child: Text('Contact (Z-A)')),
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
    final filteredCount = _filteredClients.length;
    final totalCount = _clients.length;

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
            onPressed: _loadClients,
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
          // Clients List
          Expanded(
            child: _isLoading && _clients.isEmpty
                ? const ClientListSkeleton()
                : _errorMessage != null && _clients.isEmpty
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
                              onPressed: _loadClients,
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
                    : _filteredClients.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadClients,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _filteredClients.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _filteredClients.length) {
                                  return _buildListFooter();
                                }

                                final client = _filteredClients[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _onClientSelected(client),
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
                                                  client.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  client.address ??
                                                      'No address',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (client
                                                    .contact.isNotEmpty) ...[
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
                                                        client.contact,
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                if (client.email?.isNotEmpty ==
                                                    true) ...[
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
                                                          client.email!,
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
          // Refresh after adding new client
          if (mounted) {
            _loadClients();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
