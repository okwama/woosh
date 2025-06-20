import 'package:get_storage/get_storage.dart';
import 'dart:convert';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

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
    }
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
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    final accessToken = getAccessToken();
    return accessToken != null && !isTokenExpired();
  }
}
