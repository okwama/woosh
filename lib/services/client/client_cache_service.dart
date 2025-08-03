import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/clients/client_model.dart';

/// Client Cache Service - Handles client data caching for offline functionality
class ClientCacheService {
  static const String _cacheKey = 'cached_clients';
  static const String _lastUpdateKey = 'clients_last_update';
  static const Duration _cacheValidity = Duration(hours: 24);

  /// Cache clients data
  static Future<void> cacheClients(List<Client> clients) async {
    try {
      final box = GetStorage();
      final clientData = clients.map((client) => client.toJson()).toList();

      await box.write(_cacheKey, clientData);
      await box.write(_lastUpdateKey, DateTime.now().toIso8601String());

      print('✅ Cached ${clients.length} clients');
    } catch (e) {
      print('❌ Failed to cache clients: $e');
    }
  }

  /// Get cached clients
  static List<Client> getCachedClients() {
    try {
      final box = GetStorage();
      final clientData = box.read(_cacheKey) as List<dynamic>?;

      if (clientData != null) {
        final clients = clientData
            .map((json) => Client.fromJson(json as Map<String, dynamic>))
            .toList();

        print('📋 Retrieved ${clients.length} cached clients');
        return clients;
      }
    } catch (e) {
      print('❌ Failed to get cached clients: $e');
    }

    return [];
  }

  /// Check if cache is valid
  static bool isCacheValid() {
    try {
      final box = GetStorage();
      final lastUpdateStr = box.read(_lastUpdateKey) as String?;

      if (lastUpdateStr != null) {
        final lastUpdate = DateTime.parse(lastUpdateStr);
        final now = DateTime.now();
        final isValid = now.difference(lastUpdate) < _cacheValidity;

        print('📋 Cache validity: $isValid (last update: $lastUpdate)');
        return isValid;
      }
    } catch (e) {
      print('❌ Failed to check cache validity: $e');
    }

    return false;
  }

  /// Clear client cache
  static Future<void> clearCache() async {
    try {
      final box = GetStorage();
      await box.remove(_cacheKey);
      await box.remove(_lastUpdateKey);

      print('🗑️ Cleared client cache');
    } catch (e) {
      print('❌ Failed to clear client cache: $e');
    }
  }

  /// Get cache info
  static Map<String, dynamic> getCacheInfo() {
    try {
      final box = GetStorage();
      final lastUpdateStr = box.read(_lastUpdateKey) as String?;
      final clientData = box.read(_cacheKey) as List<dynamic>?;

      return {
        'hasCache': clientData != null,
        'cacheSize': clientData?.length ?? 0,
        'lastUpdate': lastUpdateStr,
        'isValid': isCacheValid(),
      };
    } catch (e) {
      print('❌ Failed to get cache info: $e');
      return {
        'hasCache': false,
        'cacheSize': 0,
        'lastUpdate': null,
        'isValid': false,
      };
    }
  }
}
