import 'package:get/get.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:woosh/services/client/client_service.dart';
import 'package:woosh/services/client/client_cache_service.dart';

/// Client State Service - Manages client state across the app
class ClientStateService extends GetxController {
  // Observable variables
  final clients = <Client>[].obs;
  final isLoading = false.obs;
  final error = Rxn<String>();
  final selectedClient = Rxn<Client>();
  final searchQuery = ''.obs;
  final currentPage = 1.obs;
  final hasMoreData = true.obs;

  // Filters
  final selectedRouteId = Rxn<int>();
  final selectedCountryId = Rxn<int>();
  final selectedRegionId = Rxn<int>();

  @override
  void onInit() {
    super.onInit();
    _loadCachedClients();
  }

  /// Load cached clients on startup
  void _loadCachedClients() {
    final cachedClients = ClientCacheService.getCachedClients();
    if (cachedClients.isNotEmpty) {
      clients.value = cachedClients;
      print('📋 Loaded ${cachedClients.length} cached clients');
    }
  }

  /// Fetch clients from API
  Future<void> fetchClients({
    bool refresh = false,
    int? routeId,
    int? countryId,
    int? regionId,
    String? query,
  }) async {
    try {
      isLoading.value = true;
      error.value = null;

      if (refresh) {
        currentPage.value = 1;
        hasMoreData.value = true;
      }

      print('📋 Fetching clients...');

      final response = await ClientService.fetchClients(
        routeId: routeId ?? selectedRouteId.value,
        countryId: countryId ?? selectedCountryId.value,
        regionId: regionId ?? selectedRegionId.value,
        query: query ?? searchQuery.value,
        page: currentPage.value,
        limit: 50,
      );

      final List<dynamic> clientData = response['data'] ?? [];
      final newClients = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      if (refresh || currentPage.value == 1) {
        clients.value = newClients;
      } else {
        clients.addAll(newClients);
      }

      // Update pagination
      hasMoreData.value = newClients.length >= 50;
      if (hasMoreData.value) {
        currentPage.value++;
      }

      // Cache the results
      await ClientCacheService.cacheClients(clients);

      print('✅ Fetched ${newClients.length} clients');
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to fetch clients: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Search clients
  Future<void> searchClients({
    String? query,
    int? countryId,
    int? regionId,
    int? routeId,
    int? status,
  }) async {
    try {
      isLoading.value = true;
      error.value = null;

      print('🔍 Searching clients...');

      final response = await ClientService.searchClients(
        query: query,
        countryId: countryId,
        regionId: regionId,
        routeId: routeId,
        status: status,
      );

      final List<dynamic> clientData = response['data'] ?? [];
      final searchResults = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      clients.value = searchResults;

      print('✅ Found ${searchResults.length} clients');
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to search clients: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get client by ID
  Future<Client?> getClientById(int clientId) async {
    try {
      print('📋 Getting client details for ID: $clientId');

      final response = await ClientService.getClientById(clientId);
      final client = Client.fromJson(response);

      selectedClient.value = client;
      return client;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to get client: $e');
      return null;
    }
  }

  /// Create new client
  Future<bool> createClient(Map<String, dynamic> clientData) async {
    try {
      isLoading.value = true;
      error.value = null;

      print('➕ Creating new client...');

      final response = await ClientService.createClient(clientData);
      final newClient = Client.fromJson(response);

      // Add to list
      clients.insert(0, newClient);

      // Update cache
      await ClientCacheService.cacheClients(clients);

      print('✅ Created new client: ${newClient.name}');
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to create client: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update client
  Future<bool> updateClient(
      int clientId, Map<String, dynamic> clientData) async {
    try {
      isLoading.value = true;
      error.value = null;

      print('✏️ Updating client ID: $clientId');

      final response = await ClientService.updateClient(clientId, clientData);
      final updatedClient = Client.fromJson(response);

      // Update in list
      final index = clients.indexWhere((client) => client.id == clientId);
      if (index != -1) {
        clients[index] = updatedClient;
      }

      // Update selected client if it's the same
      if (selectedClient.value?.id == clientId) {
        selectedClient.value = updatedClient;
      }

      // Update cache
      await ClientCacheService.cacheClients(clients);

      print('✅ Updated client: ${updatedClient.name}');
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to update client: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Set filters
  void setFilters({
    int? routeId,
    int? countryId,
    int? regionId,
    String? query,
  }) {
    selectedRouteId.value = routeId;
    selectedCountryId.value = countryId;
    selectedRegionId.value = regionId;
    searchQuery.value = query ?? '';

    // Refresh with new filters
    fetchClients(refresh: true);
  }

  /// Clear filters
  void clearFilters() {
    selectedRouteId.value = null;
    selectedCountryId.value = null;
    selectedRegionId.value = null;
    searchQuery.value = '';

    // Refresh without filters
    fetchClients(refresh: true);
  }

  /// Load more clients (pagination)
  Future<void> loadMoreClients() async {
    if (!hasMoreData.value || isLoading.value) return;

    await fetchClients();
  }

  /// Refresh clients
  Future<void> refreshClients() async {
    await fetchClients(refresh: true);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await ClientCacheService.clearCache();
    clients.clear();
    selectedClient.value = null;
  }

  /// Get cache info
  Map<String, dynamic> getCacheInfo() {
    return ClientCacheService.getCacheInfo();
  }

  /// Fetch clients from API (basic fields only)
  Future<void> fetchClientsBasic({
    bool refresh = false,
    int? routeId,
    int? countryId,
    int? regionId,
    String? query,
  }) async {
    try {
      isLoading.value = true;
      error.value = null;

      if (refresh) {
        currentPage.value = 1;
        hasMoreData.value = true;
      }

      print('📋 Fetching clients (basic fields)...');

      final response = await ClientService.fetchClientsBasic(
        routeId: routeId ?? selectedRouteId.value,
        countryId: countryId ?? selectedCountryId.value,
        regionId: regionId ?? selectedRegionId.value,
        query: query ?? searchQuery.value,
        page: currentPage.value,
        limit: 50,
      );

      final List<dynamic> clientData = response['data'] ?? [];
      final newClients = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      if (refresh || currentPage.value == 1) {
        clients.value = newClients;
      } else {
        clients.addAll(newClients);
      }

      // Update pagination
      hasMoreData.value = newClients.length >= 50;
      if (hasMoreData.value) {
        currentPage.value++;
      }

      // Cache the results
      await ClientCacheService.cacheClients(clients);

      print('✅ Fetched ${newClients.length} clients (basic fields)');
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to fetch clients basic: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Search clients (basic fields only)
  Future<void> searchClientsBasic({
    String? query,
    int? countryId,
    int? regionId,
    int? routeId,
    int? status,
  }) async {
    try {
      isLoading.value = true;
      error.value = null;

      print('🔍 Searching clients (basic fields)...');

      final response = await ClientService.searchClientsBasic(
        query: query,
        countryId: countryId,
        regionId: regionId,
        routeId: routeId,
        status: status,
      );

      final List<dynamic> clientData = response['data'] ?? [];
      final searchResults = clientData
          .map((json) => Client.fromJson(json as Map<String, dynamic>))
          .toList();

      clients.value = searchResults;

      print('✅ Found ${searchResults.length} clients (basic fields)');
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to search clients basic: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get client by ID (basic fields only)
  Future<Client?> getClientByIdBasic(int clientId) async {
    try {
      print('📋 Getting client details (basic) for ID: $clientId');

      final response = await ClientService.getClientByIdBasic(clientId);
      final client = Client.fromJson(response);

      selectedClient.value = client;
      return client;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to get client basic: $e');
      return null;
    }
  }
}
