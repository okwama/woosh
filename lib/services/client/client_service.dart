import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/models/clients/client_model.dart';

/// Client Service - Modular client-related API operations
///
/// This service handles all client operations:
/// - Fetch clients with filtering and pagination
/// - Search clients by various criteria
/// - Get client details
/// - Create/Update/Delete clients
/// - Get client statistics
class ClientService {
  static const String baseUrl = '${Config.baseUrl}/clients';

  /// Get authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
    };

    // Check if token is expired and refresh if needed
    if (TokenService.isTokenExpired()) {
      final refreshed = await ApiService.refreshAccessToken();
      if (!refreshed) {
        throw Exception('Authentication required');
      }
    }

    final accessToken = TokenService.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  /// Fetch clients with filtering and pagination
  static Future<Map<String, dynamic>> fetchClients({
    int? routeId,
    int? countryId,
    int? regionId,
    String? query,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      print('📋 Fetching clients with filters...');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (routeId != null) queryParams['routeId'] = routeId.toString();
      if (countryId != null) queryParams['countryId'] = countryId.toString();
      if (regionId != null) queryParams['regionId'] = regionId.toString();
      if (query != null && query.isNotEmpty) queryParams['query'] = query;

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('📋 Fetch clients response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': page,
            'limit': limit,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception('Failed to fetch clients: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Fetch clients failed: $e');
      throw Exception('Failed to fetch clients: $e');
    }
  }

  /// Search clients with advanced filters
  static Future<Map<String, dynamic>> searchClients({
    String? query,
    int? countryId,
    int? regionId,
    int? routeId,
    int? status,
  }) async {
    try {
      print('🔍 Searching clients...');

      final queryParams = <String, String>{};
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      if (countryId != null) queryParams['countryId'] = countryId.toString();
      if (regionId != null) queryParams['regionId'] = regionId.toString();
      if (routeId != null) queryParams['routeId'] = routeId.toString();
      if (status != null) queryParams['status'] = status.toString();

      final uri =
          Uri.parse('$baseUrl/search').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('🔍 Search clients response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception('Failed to search clients: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Search clients failed: $e');
      throw Exception('Failed to search clients: $e');
    }
  }

  /// Get client by ID
  static Future<Map<String, dynamic>> getClientById(int clientId) async {
    try {
      print('📋 Getting client details for ID: $clientId');

      final response = await http.get(
        Uri.parse('$baseUrl/$clientId'),
        headers: await _getAuthHeaders(),
      );

      print('📋 Get client response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get client: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Failed to get client: $e');
      throw Exception('Failed to get client: $e');
    }
  }

  /// Create new client
  static Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> clientData) async {
    try {
      print('➕ Creating new client...');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await _getAuthHeaders(),
        body: json.encode(clientData),
      );

      print('➕ Create client response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create client');
      }
    } catch (e) {
      print('❌ Failed to create client: $e');
      throw Exception('Failed to create client: $e');
    }
  }

  /// Update client
  static Future<Map<String, dynamic>> updateClient(
      int clientId, Map<String, dynamic> clientData) async {
    try {
      print('✏️ Updating client ID: $clientId');

      final response = await http.patch(
        Uri.parse('$baseUrl/$clientId'),
        headers: await _getAuthHeaders(),
        body: json.encode(clientData),
      );

      print('✏️ Update client response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update client');
      }
    } catch (e) {
      print('❌ Failed to update client: $e');
      throw Exception('Failed to update client: $e');
    }
  }

  /// Get clients by country
  static Future<Map<String, dynamic>> getClientsByCountry(int countryId) async {
    try {
      print('🌍 Getting clients for country ID: $countryId');

      final response = await http.get(
        Uri.parse('$baseUrl/country/$countryId'),
        headers: await _getAuthHeaders(),
      );

      print('🌍 Get clients by country response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception(
            'Failed to get clients by country: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get clients by country failed: $e');
      throw Exception('Failed to get clients by country: $e');
    }
  }

  /// Get clients by region
  static Future<Map<String, dynamic>> getClientsByRegion(int regionId) async {
    try {
      print('🏘️ Getting clients for region ID: $regionId');

      final response = await http.get(
        Uri.parse('$baseUrl/region/$regionId'),
        headers: await _getAuthHeaders(),
      );

      print('🏘️ Get clients by region response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception(
            'Failed to get clients by region: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get clients by region failed: $e');
      throw Exception('Failed to get clients by region: $e');
    }
  }

  /// Get clients by route
  static Future<Map<String, dynamic>> getClientsByRoute(int routeId) async {
    try {
      print('🛣️ Getting clients for route ID: $routeId');

      final response = await http.get(
        Uri.parse('$baseUrl/route/$routeId'),
        headers: await _getAuthHeaders(),
      );

      print('🛣️ Get clients by route response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception(
            'Failed to get clients by route: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get clients by route failed: $e');
      throw Exception('Failed to get clients by route: $e');
    }
  }

  /// Get clients by location (nearby)
  static Future<Map<String, dynamic>> getClientsByLocation({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      print(
          '📍 Getting clients near location: $latitude, $longitude (radius: ${radius}km)');

      final queryParams = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      };

      final uri =
          Uri.parse('$baseUrl/location').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('📍 Get clients by location response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception(
            'Failed to get clients by location: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get clients by location failed: $e');
      throw Exception('Failed to get clients by location: $e');
    }
  }

  /// Get client statistics
  static Future<Map<String, dynamic>> getClientStats({
    int? countryId,
    int? regionId,
  }) async {
    try {
      print('📊 Getting client statistics...');

      final queryParams = <String, String>{};
      if (countryId != null) queryParams['countryId'] = countryId.toString();
      if (regionId != null) queryParams['regionId'] = regionId.toString();

      final uri =
          Uri.parse('$baseUrl/stats').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('📊 Get client stats response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
            'Failed to get client statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get client stats failed: $e');
      throw Exception('Failed to get client statistics: $e');
    }
  }

  /// Fetch clients with filtering and pagination (basic fields only)
  static Future<Map<String, dynamic>> fetchClientsBasic({
    int? routeId,
    int? countryId,
    int? regionId,
    String? query,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      print('📋 Fetching clients (basic fields)...');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (routeId != null) queryParams['routeId'] = routeId.toString();
      if (countryId != null) queryParams['countryId'] = countryId.toString();
      if (regionId != null) queryParams['regionId'] = regionId.toString();
      if (query != null && query.isNotEmpty) queryParams['query'] = query;

      final uri =
          Uri.parse('$baseUrl/basic').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('📋 Fetch clients basic response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': page,
            'limit': limit,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception('Failed to fetch clients: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Failed to fetch clients basic: $e');
      throw Exception('Failed to fetch clients: $e');
    }
  }

  /// Search clients with basic fields only
  static Future<Map<String, dynamic>> searchClientsBasic({
    String? query,
    int? countryId,
    int? regionId,
    int? routeId,
    int? status,
  }) async {
    try {
      print('🔍 Searching clients (basic fields)...');

      final queryParams = <String, String>{};
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      if (countryId != null) queryParams['countryId'] = countryId.toString();
      if (regionId != null) queryParams['regionId'] = regionId.toString();
      if (routeId != null) queryParams['routeId'] = routeId.toString();
      if (status != null) queryParams['status'] = status.toString();

      final uri = Uri.parse('$baseUrl/search/basic')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      print('🔍 Search clients basic response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both array and paginated response formats
        if (data is List) {
          // Backend returned array directly
          return {
            'data': data,
            'total': data.length,
            'page': 1,
            'limit': data.length,
            'totalPages': 1,
          };
        } else if (data is Map<String, dynamic>) {
          // Backend returned paginated response
          return data;
        } else {
          throw Exception('Unexpected response format from server');
        }
      } else {
        throw Exception('Failed to search clients: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Failed to search clients basic: $e');
      throw Exception('Failed to search clients: $e');
    }
  }

  /// Get client by ID (basic fields only)
  static Future<Map<String, dynamic>> getClientByIdBasic(int clientId) async {
    try {
      print('📋 Getting client details (basic) for ID: $clientId');

      final response = await http.get(
        Uri.parse('$baseUrl/$clientId/basic'),
        headers: await _getAuthHeaders(),
      );

      print('📋 Get client basic response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get client: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Failed to get client basic: $e');
      throw Exception('Failed to get client: $e');
    }
  }
}
