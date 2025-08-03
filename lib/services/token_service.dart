import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'dart:async';
import 'package:woosh/services/api_service.dart';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  // Proactive refresh timer
  static Timer? _refreshTimer;

  // Store tokens after login
  static Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    final box = GetStorage();
    await box.write(_accessTokenKey, accessToken);
    await box.write(_refreshTokenKey, refreshToken);

    if (expiresIn != null) {
      final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
      await box.write(_tokenExpiryKey, expiryTime.toIso8601String());

      // Start proactive refresh timer
      _startProactiveRefresh(expiresIn);
    }
  }

  // Start proactive token refresh
  static void _startProactiveRefresh(int expiresIn) {
    _refreshTimer?.cancel();

    // Refresh token 5 minutes before expiry
    final refreshTime = expiresIn - 300; // 5 minutes before expiry
    if (refreshTime > 0) {
      _refreshTimer = Timer(Duration(seconds: refreshTime), () async {
        print('🔄 Proactive token refresh triggered');
        try {
          final refreshed = await ApiService.refreshAccessToken();
          if (refreshed) {
            print('✅ Proactive token refresh successful');
          } else {
            print('❌ Proactive token refresh failed');
          }
        } catch (e) {
          print('❌ Proactive token refresh error: $e');
        }
      });
    }
  }

  // Stop proactive refresh timer
  static void _stopProactiveRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Get access token
  static String? getAccessToken() {
    final box = GetStorage();
    return box.read<String>(_accessTokenKey);
  }

  // Get refresh token
  static String? getRefreshToken() {
    final box = GetStorage();
    return box.read<String>(_refreshTokenKey);
  }

  // Check if token is expired
  static bool isTokenExpired() {
    final box = GetStorage();
    final expiryString = box.read<String>(_tokenExpiryKey);
    if (expiryString == null) return true;

    final expiryTime = DateTime.parse(expiryString);
    return DateTime.now().isAfter(expiryTime);
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    final box = GetStorage();
    await box.remove(_accessTokenKey);
    await box.remove(_refreshTokenKey);
    await box.remove(_tokenExpiryKey);

    // Stop proactive refresh timer
    _stopProactiveRefresh();
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    final accessToken = getAccessToken();
    final refreshToken = getRefreshToken();

    // User is authenticated if they have both tokens and access token is not expired
    return accessToken != null && refreshToken != null && !isTokenExpired();
  }

  // Check if user has valid refresh token (for offline scenarios)
  static bool hasValidRefreshToken() {
    final refreshToken = getRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  // Get token expiry time
  static DateTime? getTokenExpiry() {
    final box = GetStorage();
    final expiryString = box.read<String>(_tokenExpiryKey);
    if (expiryString == null) return null;

    try {
      return DateTime.parse(expiryString);
    } catch (e) {
      print('Error parsing token expiry: $e');
      return null;
    }
  }

  // Check if token will expire soon (within 5 minutes)
  static bool isTokenExpiringSoon() {
    final expiry = getTokenExpiry();
    if (expiry == null) return true;

    final now = DateTime.now();
    final timeUntilExpiry = expiry.difference(now);
    return timeUntilExpiry.inMinutes <= 5;
  }
}
