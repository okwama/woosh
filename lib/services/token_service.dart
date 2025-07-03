import 'package:get_storage/get_storage.dart';
import 'dart:convert';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
<<<<<<< HEAD
=======
  static bool _isLoginInProgress = false;

  // Set login in progress flag
  static void setLoginInProgress(bool inProgress) {
    _isLoginInProgress = inProgress;
    print('🔐 Login in progress: $_isLoginInProgress');
  }
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

  // Store tokens after login
  static Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
<<<<<<< HEAD
=======
    print('💾 TokenService.storeTokens() called');
    print('💾 Access token length: ${accessToken.length}');
    print('💾 Refresh token length: ${refreshToken.length}');
    print('💾 Expires in: ${expiresIn ?? 'not set'} seconds');

>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    final box = GetStorage();
    await box.write(_accessTokenKey, accessToken);
    await box.write(_refreshTokenKey, refreshToken);

    if (expiresIn != null) {
      final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
      await box.write(_tokenExpiryKey, expiryTime.toIso8601String());
<<<<<<< HEAD
    }
=======
      print('💾 Token expiry set to: ${expiryTime.toIso8601String()}');
    }

    print('💾 Tokens stored successfully');
    print(
        '💾 Verification - Access token stored: ${box.read<String>(_accessTokenKey) != null}');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  }

  // Get access token
  static String? getAccessToken() {
    final box = GetStorage();
<<<<<<< HEAD
    return box.read<String>(_accessTokenKey);
=======
    final token = box.read<String>(_accessTokenKey);
    print('🔑 TokenService.getAccessToken() called');
    print('🔑 Token present: ${token != null}');
    print('🔑 Token length: ${token?.length ?? 0}');
    if (token == null) {
      print('🔑 WARNING: No access token found in storage');
      print('🔑 Available keys in storage: ${box.getKeys()}');
    }
    return token;
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
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
<<<<<<< HEAD
=======
    if (_isLoginInProgress) {
      print('🗑️ WARNING: Attempted to clear tokens during login - BLOCKED');
      return;
    }

    print('🗑️ TokenService.clearTokens() called');
    print('🗑️ Clearing all tokens from storage');

>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
    final box = GetStorage();
    await box.remove(_accessTokenKey);
    await box.remove(_refreshTokenKey);
    await box.remove(_tokenExpiryKey);
<<<<<<< HEAD
=======

    print('🗑️ Tokens cleared successfully');
    print('🗑️ Available keys after clearing: ${box.getKeys()}');
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    final accessToken = getAccessToken();
    return accessToken != null && !isTokenExpired();
  }
<<<<<<< HEAD
=======

  // Get token expiry time
  static DateTime? getTokenExpiry() {
    final box = GetStorage();
    final expiryString = box.read<String>(_tokenExpiryKey);
    if (expiryString == null) return null;
    return DateTime.parse(expiryString);
  }

  // Get time until token expires
  static Duration? getTimeUntilExpiry() {
    final expiry = getTokenExpiry();
    if (expiry == null) return null;
    return expiry.difference(DateTime.now());
  }

  // Check if token will expire soon (within specified duration)
  static bool willExpireSoon(
      [Duration threshold = const Duration(minutes: 30)]) {
    final timeUntilExpiry = getTimeUntilExpiry();
    if (timeUntilExpiry == null) return true;
    return timeUntilExpiry <= threshold;
  }

  // Get user ID from token (if available in JWT payload)
  static String? getUserIdFromToken() {
    try {
      final token = getAccessToken();
      if (token == null) return null;

      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> decodedMap = json.decode(decoded);

      return decodedMap['userId']?.toString();
    } catch (e) {
      print('Error extracting user ID from token: $e');
      return null;
    }
  }

  // Debug method to print token information
  static void debugTokenInfo() {
    final accessToken = getAccessToken();
    final refreshToken = getRefreshToken();
    final expiry = getTokenExpiry();
    final timeUntilExpiry = getTimeUntilExpiry();
    final isExpired = isTokenExpired();
    final isAuth = isAuthenticated();

    print('=== Token Debug Info ===');
    print(
        'Access Token: ${accessToken != null ? 'Present (${accessToken.length} chars)' : 'Missing'}');
    print(
        'Refresh Token: ${refreshToken != null ? 'Present (${refreshToken.length} chars)' : 'Missing'}');
    print('Expiry Time: ${expiry?.toIso8601String() ?? 'Not set'}');
    print(
        'Time Until Expiry: ${timeUntilExpiry?.inMinutes ?? 'Unknown'} minutes');
    print('Is Expired: $isExpired');
    print('Is Authenticated: $isAuth');
    print('Will Expire Soon: ${willExpireSoon()}');
    print('User ID: ${getUserIdFromToken()}');
    print('========================');
  }
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
}
