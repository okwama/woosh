import 'package:woosh/services/token_service.dart';
import 'package:woosh/services/api_service.dart';

class RefreshTokenTest {
  static Future<void> testTokenStorage() async {
    print('=== REFRESH TOKEN TEST ===');

    // Test current state
    print('1. Current authentication state:');
    print('   - Is authenticated: ${TokenService.isAuthenticated()}');
    print(
        '   - Access token: ${TokenService.getAccessToken() != null ? "Present" : "Missing"}');
    print(
        '   - Refresh token: ${TokenService.getRefreshToken() != null ? "Present" : "Missing"}');
    print('   - Token expired: ${TokenService.isTokenExpired()}');

    // Test API call
    print('\n2. Testing API call:');
    try {
      final clients = await ApiService.fetchClients(limit: 1);
      print(
          '   ✅ API call successful - fetched ${clients.data.length} clients');
    } catch (e) {
      print('   ❌ API call failed: $e');
    }

    // Test token refresh
    print('\n3. Testing token refresh:');
    try {
      final refreshed = await ApiService.refreshAccessToken();
      print(
          '   ${refreshed ? "✅" : "❌"} Token refresh: ${refreshed ? "Success" : "Failed"}');
    } catch (e) {
      print('   ❌ Token refresh error: $e');
    }

    print('\n=== TEST COMPLETE ===');
  }

  static Future<void> testLoginFlow() async {
    print('=== LOGIN FLOW TEST ===');

    // This would be called after a successful login
    print('1. Simulating successful login...');

    // Test if tokens are stored
    final isAuthenticated = TokenService.isAuthenticated();
    print('2. Authentication check: $isAuthenticated');

    if (isAuthenticated) {
      print('3. Testing API access...');
      try {
        final clients = await ApiService.fetchClients(limit: 1);
        print('   ✅ API access working - ${clients.data.length} clients');
      } catch (e) {
        print('   ❌ API access failed: $e');
      }
    }

    print('=== LOGIN FLOW TEST COMPLETE ===');
  }
}
