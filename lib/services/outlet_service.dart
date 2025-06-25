import 'package:get/get.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/hive/client_hive_service.dart';
import 'package:glamour_queen/models/hive/client_model.dart';
import 'package:glamour_queen/services/outlet_search.dart';

// Helper classes for search functionality
class _Match {
  final int start;
  final int end;
  _Match(this.start, this.end);
}

class _ScoredOutlet {
  final Outlet outlet;
  final double score;
  _ScoredOutlet(this.outlet, this.score);
}

class OutletState {
  final List<Outlet> outlets;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreData;
  final int currentPage;
  final DateTime lastUpdateTime;
  final String? error;
  final String? searchQuery;
  final String? timeFilter;

  OutletState({
    required this.outlets,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.currentPage,
    required this.lastUpdateTime,
    this.error,
    this.searchQuery,
    this.timeFilter,
  });

  OutletState copyWith({
    List<Outlet>? outlets,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreData,
    int? currentPage,
    DateTime? lastUpdateTime,
    String? error,
    String? searchQuery,
    String? timeFilter,
  }) {
    return OutletState(
      outlets: outlets ?? this.outlets,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentPage: currentPage ?? this.currentPage,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      timeFilter: timeFilter ?? this.timeFilter,
    );
  }
}

class OutletService extends GetxService {
  static const int _pageSize = 2000; // Server limit appears to be 2000
  static const int _maxRetries = 3;

  // Single source of truth for state
  final Rx<OutletState> _state = OutletState(
    outlets: [],
    isLoading: true, // Start with loading state
    isLoadingMore: false,
    hasMoreData: true,
    currentPage: 1,
    lastUpdateTime: DateTime.now(),
  ).obs;

  // Keep track of all loaded outlets
  final List<Outlet> _allOutlets = [];
  final Map<String, List<Outlet>> _searchCache = {};

  // Public getters
  OutletState get state => _state.value;
  List<Outlet> get outlets => _getFilteredOutlets();
  bool get isLoading => _state.value.isLoading;
  bool get isLoadingMore => _state.value.isLoadingMore;
  bool get hasMoreData => _state.value.hasMoreData;
  int get allOutletsCount => _allOutlets.length;

  // Stream for state updates
  Stream<OutletState> get stateStream => _state.stream;

  @override
  void onInit() {
    super.onInit();
    // Immediately start loading data
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // First try to load from cache
      await _loadFromCache();

      // Then fetch fresh data
      await _loadNextPage(reset: true);
    } catch (e) {
      print('? Error in initial data load: $e');
      _updateState(_state.value.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> loadMoreOutlets() async {
    if (_state.value.isLoadingMore || !_state.value.hasMoreData) return;

    _updateState(_state.value.copyWith(isLoadingMore: true));

    try {
      await _loadNextPage();
    } catch (e) {
      print('? Error loading more outlets: $e');
      _updateState(_state.value.copyWith(
        error: e.toString(),
        isLoadingMore: false,
      ));
    }
  }

  Future<void> refresh() async {
    if (_state.value.isLoading) return;

    _updateState(_state.value.copyWith(
      isLoading: true,
      error: null,
    ));

    try {
      await _loadNextPage(reset: true);
    } catch (e) {
      print('? Error refreshing outlets: $e');
      _updateState(_state.value.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> _loadNextPage({bool reset = false}) async {
    final currentState = _state.value;
    final pageToLoad = reset ? 1 : currentState.currentPage;

    try {
      final routeId = ApiService.getCurrentUserRouteId();
      final pageOutlets = await ApiService.fetchOutlets(
        page: pageToLoad,
        limit: _pageSize,
        routeId: routeId,
      );

      if (pageOutlets.isNotEmpty) {
        await _cacheOutlets(pageOutlets);

        if (reset) {
          _allOutlets.clear();
          _searchCache.clear();
        }
        _allOutlets.addAll(pageOutlets);

        final hasMore = pageOutlets.length == _pageSize;
        print(
            '?? Loaded ${pageOutlets.length} outlets for page $pageToLoad. Total: ${_allOutlets.length}');

        // Only update state once with accumulated results
        _updateState(currentState.copyWith(
          outlets:
              List<Outlet>.from(_allOutlets), // Use all accumulated outlets
          currentPage: pageToLoad + 1,
          hasMoreData: hasMore,
          isLoading: false,
          isLoadingMore: false,
          lastUpdateTime: DateTime.now(),
          error: null,
        ));

        // If there are more pages and this was a reset, load them immediately
        if (hasMore && reset) {
          await _loadNextPage();
        }
      } else {
        _updateState(currentState.copyWith(
          hasMoreData: false,
          isLoading: false,
          isLoadingMore: false,
          lastUpdateTime: DateTime.now(),
        ));
      }
    } catch (e) {
      print('? Error loading page $pageToLoad: $e');
      throw Exception('Failed to load outlets: $e');
    }
  }

  Future<void> addOutlet(Outlet newOutlet) async {
    final currentState = _state.value;

    try {
      // Add to beginning of list
      final updatedOutlets = [newOutlet, ...currentState.outlets];

      // Cache the new outlet
      await _cacheOutlets([newOutlet]);

      _updateState(currentState.copyWith(
        outlets: updatedOutlets,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (e) {
      print('? Error adding outlet: $e');
      _updateState(currentState.copyWith(
        error: 'Failed to add outlet: $e',
      ));
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final clientHiveService = Get.find<ClientHiveService>();
      final cachedClients = clientHiveService.getAllClients();

      if (cachedClients.isEmpty) return;

      final cachedOutlets = cachedClients.map(_mapClientToOutlet).toList();

      _updateState(_state.value.copyWith(
        outlets: cachedOutlets,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (e) {
      print('? Error loading from cache: $e');
    }
  }

  Future<void> _cacheOutlets(List<Outlet> outlets) async {
    try {
      final clientHiveService = Get.find<ClientHiveService>();
      final clientModels = outlets.map(_mapOutletToClient).toList();
      await clientHiveService.saveClients(clientModels);
    } catch (e) {
      print('? Error caching outlets: $e');
    }
  }

  void _updateState(OutletState newState) {
    // Ensure we're not losing any outlets when updating state
    final updatedState = newState.copyWith(
      outlets: newState.outlets.isEmpty ? _allOutlets : newState.outlets,
    );
    _state.value = updatedState;
    print(
        '?? State updated: ${updatedState.outlets.length} outlets, page ${updatedState.currentPage}');
  }

  ClientModel _mapOutletToClient(Outlet outlet) {
    return ClientModel(
      id: outlet.id,
      name: outlet.name,
      address: outlet.address ?? '',
      phone: outlet.contact ?? '',
      email: outlet.email ?? '',
      latitude: outlet.latitude ?? 0.0,
      longitude: outlet.longitude ?? 0.0,
      status: 'active',
    );
  }

  Outlet _mapClientToOutlet(ClientModel client) {
    return Outlet(
      id: client.id,
      name: client.name,
      address: client.address,
      contact: client.phone,
      email: client.email,
      latitude: client.latitude,
      longitude: client.longitude,
      regionId: 0,
      region: '',
      countryId: 0,
    );
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[-\s_.,;:/\\]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<_ScoredOutlet> _matchAndScoreOutlets(
      List<Outlet> outlets, List<String> patternWords) {
    final scoredOutlets = <_ScoredOutlet>[];
    final searchQuery = patternWords.join(' ').trim().toLowerCase();

    print('?? Matching outlets with query: "$searchQuery"');

    for (final outlet in outlets) {
      final name = outlet.name.trim().toLowerCase();
      final address = outlet.address?.trim().toLowerCase() ?? '';

      // Skip empty searches
      if (searchQuery.isEmpty) {
        scoredOutlets.add(_ScoredOutlet(outlet, 0.0));
        continue;
      }

      double score = 0.0;

      // Exact full string match
      if (name == searchQuery || address == searchQuery) {
        score = 1000.0;
        print('?? Exact match found for: ${outlet.name}');
      }
      // Contains exact search query as a substring
      else if (name.contains(searchQuery) || address.contains(searchQuery)) {
        score = 800.0;
        // Boost score if it matches at word boundary
        if (name.split(' ').any((word) => word == searchQuery) ||
            address.split(' ').any((word) => word == searchQuery)) {
          score = 900.0;
          print('?? Word boundary match found for: ${outlet.name}');
        }
        // Boost score if it matches at start
        if (name.startsWith(searchQuery) || address.startsWith(searchQuery)) {
          score += 50.0;
          print('? Start match found for: ${outlet.name}');
        }
      }
      // Partial word match
      else {
        final searchWords = searchQuery.split(' ');
        final nameWords = name.split(' ');
        final addressWords = address.split(' ');

        int matchedWords = 0;
        for (final searchWord in searchWords) {
          if (nameWords.any((word) => word.contains(searchWord)) ||
              addressWords.any((word) => word.contains(searchWord))) {
            matchedWords++;
          }
        }

        if (matchedWords > 0) {
          score = 500.0 * (matchedWords / searchWords.length);
          print('? Partial match found for: ${outlet.name} (Score: $score)');
        }
      }

      if (score > 0) {
        scoredOutlets.add(_ScoredOutlet(outlet, score));
      }
    }

    scoredOutlets.sort((a, b) => b.score.compareTo(a.score));
    return scoredOutlets;
  }

  List<Outlet> _getFilteredOutlets() {
    var filteredOutlets = List<Outlet>.from(_allOutlets);
    print(
        '?? Starting filtration with ${filteredOutlets.length} total outlets');

    // Apply search filter if exists
    if (_state.value.searchQuery?.isNotEmpty == true) {
      final query = _state.value.searchQuery!;

      if (_searchCache.containsKey(query)) {
        filteredOutlets = _searchCache[query]!;
        print(
            '?? Using cached search results: ${filteredOutlets.length} matches');
      } else {
        filteredOutlets = OutletSearch.searchOutlets(filteredOutlets, query);
        _searchCache[query] = filteredOutlets;
        print('?? Search results: ${filteredOutlets.length} matches found');
      }
    }

    // Apply time filter if exists
    if (_state.value.timeFilter != null) {
      print('? Applying time filter: ${_state.value.timeFilter}');
      final beforeCount = filteredOutlets.length;
      final now = DateTime.now();
      final cutoffDate = switch (_state.value.timeFilter) {
        'new' => now.subtract(const Duration(days: 1)),
        'week' => now.subtract(const Duration(days: 7)),
        'month' => now.subtract(const Duration(days: 30)),
        _ => null,
      };

      if (cutoffDate != null) {
        filteredOutlets = filteredOutlets
            .where((outlet) => outlet.createdAt?.isAfter(cutoffDate) ?? false)
            .toList();
        print(
            '?? Time filter results: ${filteredOutlets.length} matches out of $beforeCount outlets');
      }
    }

    print('? Final filtered results: ${filteredOutlets.length} outlets');
    return filteredOutlets;
  }

  Future<void> setTimeFilter(String? filter) async {
    _updateState(_state.value.copyWith(
      timeFilter: filter,
      isLoading: true,
    ));

    // Update the filtered results
    _updateState(_state.value.copyWith(
      isLoading: false,
    ));
  }

  Future<void> search(String query) async {
    print('\n?? Starting search operation with query: "${query}"');

    if (query.isEmpty) {
      print('?? Empty query - resetting to normal pagination mode');
      _updateState(_state.value.copyWith(
        searchQuery: null,
        isLoading: true,
      ));
      await _loadNextPage(reset: true);
      return;
    }

    print('? Setting loading state and preparing search...');
    _updateState(_state.value.copyWith(
      isLoading: true,
      error: null,
      searchQuery: query,
    ));

    try {
      // If we don't have all outlets yet, load them
      if (_allOutlets.length < _state.value.currentPage * _pageSize) {
        print('?? Loading all outlets for comprehensive search...');
        await _loadAllOutlets();
      } else {
        print('? Using existing ${_allOutlets.length} outlets for search');
      }

      // Update state with filtered results
      _updateState(_state.value.copyWith(
        hasMoreData: false, // Disable pagination during search
        isLoading: false,
        currentPage: 1,
        lastUpdateTime: DateTime.now(),
      ));

      print('?? Search operation completed');
    } catch (e) {
      print('? Search operation failed: $e');
      _updateState(_state.value.copyWith(
        error: 'Search failed: ${e.toString()}',
        isLoading: false,
      ));
    }
  }

  Future<void> _loadAllOutlets() async {
    try {
      final routeId = ApiService.getCurrentUserRouteId();
      final allOutlets = await ApiService.fetchOutlets(
        page: 1,
        limit: 100000, // Very large limit to get all clients
        routeId: routeId,
      );

      _allOutlets.clear();
      _allOutlets.addAll(allOutlets);

      print('?? Loaded ${allOutlets.length} total outlets');
    } catch (e) {
      print('? Error loading all outlets: $e');
      throw e;
    }
  }
}

