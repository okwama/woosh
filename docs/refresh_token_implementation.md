# Refresh Token Implementation Documentation

## Overview

This document describes the implementation of a refresh token pattern in the Whoosh Flutter application. The implementation provides secure authentication with automatic token refresh, improved user experience, and better error handling.

## Architecture

### Token Types
- **Access Token**: Short-lived (15 minutes) for API requests
- **Refresh Token**: Long-lived (7 days) for getting new access tokens

### Key Components

1. **TokenService** - Manages token storage and validation
2. **ApiService** - Handles API calls with automatic token refresh
3. **AuthController** - Manages authentication state
4. **SessionService** - Handles session management
5. **GlobalErrorHandler** - Provides consistent error handling

## Implementation Details

### 1. TokenService (`lib/services/token_service.dart`)

**Purpose**: Centralized token management using GetStorage

**Key Methods**:
```dart
// Store tokens after login
static Future<void> storeTokens({
  required String accessToken,
  required String refreshToken,
  int? expiresIn,
}) async

// Get access token
static String? getAccessToken()

// Get refresh token  
static String? getRefreshToken()

// Check if token is expired
static bool isTokenExpired()

// Clear all tokens
static Future<void> clearTokens() async

// Check if user is authenticated
static bool isAuthenticated()
```

**Storage Structure**:
- `access_token` - Current access token
- `refresh_token` - Long-lived refresh token
- `token_expiry` - Token expiration timestamp

### 2. ApiService Updates (`lib/services/api_service.dart`)

**Key Changes**:
- Updated `_getAuthToken()` to use TokenService
- Added `refreshAccessToken()` method
- Updated `_headers()` method with automatic refresh logic
- Converted all Dio calls to http package for consistency
- Enhanced error handling for 401 responses

**Automatic Refresh Flow**:
```dart
static Future<Map<String, String>> _headers([String? additionalContentType]) async {
  final token = _getAuthToken();
  
  if (await _shouldRefreshToken()) {
    final refreshed = await _refreshToken();
    if (!refreshed) {
      await logout();
      throw Exception("Session expired. Please log in again.");
    }
  }
  
  return {
    'Content-Type': additionalContentType ?? 'application/json',
    'Authorization': 'Bearer $token',
  };
}
```

**API Call Flow**:
1. Check if token is expired
2. If expired, attempt refresh
3. If refresh fails, logout user
4. If refresh succeeds, retry original request
5. Handle 401 responses with automatic refresh

### 3. AuthController Updates (`lib/controllers/auth_controller.dart`)

**Key Changes**:
- Integrated with TokenService
- Updated login/logout flows
- Added authentication state checking

**Login Flow**:
```dart
Future<void> login(String phoneNumber, String password) async {
  final response = await ApiService().login(phoneNumber, password);
  if (response['success'] == true) {
    // Tokens are automatically stored by ApiService
    _currentUser.value = user;
    _isLoggedIn.value = true;
  }
}
```

### 4. SessionService Updates (`lib/services/session_service.dart`)

**Key Changes**:
- Updated `_getAuthHeaders()` to use new token system
- Integrated automatic token refresh
- Enhanced error handling

### 5. GlobalErrorHandler (`lib/utils/error_handler.dart`)

**Purpose**: Centralized error handling for authentication issues

**Key Features**:
- Handles authentication errors (401, token expired)
- Provides user-friendly error messages
- Automatic logout and redirect on authentication failures
- Network error handling

## API Endpoints

### Authentication Endpoints

#### Login
```
POST /api/auth/login
Content-Type: application/json

{
  "phoneNumber": "1234567890",
  "password": "password123"
}

Response:
{
  "success": true,
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 900,
  "salesRep": { ... }
}
```

#### Refresh Token
```
POST /api/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}

Response:
{
  "success": true,
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 900
}
```

#### Logout
```
POST /api/auth/logout
Authorization: Bearer <accessToken>

Response:
{
  "success": true,
  "message": "Logged out successfully"
}
```

## User Experience Flow

### 1. Login Process
1. User enters credentials
2. App calls `/auth/login`
3. Server returns access + refresh tokens
4. Tokens stored securely
5. User navigated to home

### 2. API Request Flow
1. App makes API request
2. `_headers()` checks token expiration
3. If expired, automatically refresh
4. Request sent with valid token
5. Response processed normally

### 3. Token Refresh Flow
1. Access token expires
2. API call detects expiration
3. App calls `/auth/refresh` with refresh token
4. Server returns new access token
5. Original request retried with new token

### 4. Error Handling Flow
1. API returns 401 (unauthorized)
2. App attempts token refresh
3. If refresh succeeds, retry request
4. If refresh fails, logout user
5. Redirect to login screen

## Security Features

### 1. Token Validation
- Access tokens validated on every request
- Refresh tokens validated when refreshing
- Both tokens checked against server blacklist

### 2. Token Storage
- Access tokens stored in GetStorage (less sensitive)
- Refresh tokens stored in GetStorage (more sensitive)
- Token expiration tracked locally

### 3. Automatic Cleanup
- Expired tokens automatically cleared
- Logout clears all tokens
- Session timeout handling

## Error Handling

### Common Error Scenarios

#### 1. Network Connectivity Issues
```dart
// Handled by GlobalErrorHandler
if (error.toString().contains('SocketException')) {
  errorMessage = "Network error. Please check your connection.";
}
```

#### 2. Token Expiration
```dart
// Automatic refresh attempt
if (response.statusCode == 401) {
  final refreshed = await refreshAccessToken();
  if (!refreshed) {
    await logout();
    throw Exception("Session expired. Please log in again.");
  }
}
```

#### 3. Server Errors
```dart
// Graceful degradation
if (response.statusCode == 500) {
  errorMessage = "Server error. Please try again later.";
}
```

## Testing

### Test Utility (`lib/utils/test_refresh_token.dart`)

**Usage**:
```dart
// Test current token state
await RefreshTokenTest.testTokenStorage();

// Test login flow
await RefreshTokenTest.testLoginFlow();
```

**Test Scenarios**:
1. Token storage and retrieval
2. API call with valid tokens
3. Token refresh functionality
4. Authentication state checking
5. Error handling

### Manual Testing Steps

1. **Login Test**:
   - Login with valid credentials
   - Check console for token storage logs
   - Verify both tokens are stored

2. **API Call Test**:
   - Make API calls after login
   - Check console for authorization headers
   - Verify requests succeed

3. **Token Refresh Test**:
   - Wait for token expiration (or force it)
   - Make API call
   - Check console for refresh logs
   - Verify automatic refresh works

4. **Logout Test**:
   - Logout from app
   - Check console for token clearing logs
   - Verify tokens are removed

## Debug Logging

### Console Output Examples

**Successful Login**:
```
🔐 Attempting login for: 1234567890
🔐 Login response status: 200
🔐 Parsed response data keys: accessToken, refreshToken, salesRep, expiresIn
✅ Tokens stored successfully
```

**API Call with Token**:
```
🔑 Current access token: Present
🔑 Token preview: eyJhbGciOiJIUzI1NiIs...
📤 Request headers prepared: Content-Type, Authorization
📤 Authorization header: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Token Refresh**:
```
🔄 Token needs refresh, attempting...
✅ Token refreshed successfully
🔑 New token after refresh: Present
```

**Error Handling**:
```
❌ Token refresh failed
❌ Session expired. Please log in again.
```

## Migration Notes

### From Old Token System

**Changes Made**:
1. Replaced single token with access + refresh tokens
2. Updated all API calls to use `_headers()` method
3. Converted Dio calls to http package
4. Enhanced error handling
5. Added automatic token refresh

**Backward Compatibility**:
- Existing login flow works with new token structure
- API endpoints remain the same
- User experience improved with automatic refresh

### Breaking Changes

1. **Token Storage**: Now uses separate access and refresh tokens
2. **API Headers**: All requests must use `_headers()` method
3. **Error Handling**: 401 errors now trigger automatic refresh

## Performance Considerations

### 1. Token Refresh Optimization
- Refresh only when token is close to expiration
- Cache refresh results to prevent multiple requests
- Background refresh to minimize user impact

### 2. Network Efficiency
- Minimal token validation overhead
- Efficient error handling
- Graceful degradation on network issues

### 3. Storage Optimization
- Compact token storage
- Automatic cleanup of expired tokens
- Efficient token validation

## Future Enhancements

### 1. Enhanced Security
- Biometric authentication integration
- Token encryption at rest
- Advanced token validation

### 2. Performance Improvements
- Token pre-refresh
- Background sync
- Offline token validation

### 3. User Experience
- Seamless token refresh
- Better error messages
- Session recovery

## Troubleshooting

### Common Issues

#### 1. "Access token required" Error
**Cause**: Token not being sent in request headers
**Solution**: Check if `_headers()` method is being used

#### 2. Token Refresh Fails
**Cause**: Refresh token expired or invalid
**Solution**: Force user to login again

#### 3. API Calls Fail After Login
**Cause**: Token storage issues
**Solution**: Check TokenService implementation

### Debug Steps

1. Check console logs for token flow
2. Verify token storage in GetStorage
3. Test API calls manually
4. Check server logs for authentication issues

## Conclusion

The refresh token implementation provides:
- ✅ Enhanced security with short-lived access tokens
- ✅ Better user experience with automatic refresh
- ✅ Improved error handling and recovery
- ✅ Consistent API authentication
- ✅ Comprehensive logging and debugging

This implementation follows security best practices and provides a robust foundation for authentication in the Whoosh application. 