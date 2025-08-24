# Flutter Fixes Reference Guide
*Based on Woosh App Architecture Review*

## Table of Contents
1. [Security Fixes](#1-security-fixes)
2. [Performance Optimizations](#2-performance-optimizations)
3. [Routing & Navigation](#3-routing--navigation)
4. [State Management](#4-state-management)
5. [Code Quality & Linting](#5-code-quality--linting)
6. [Architecture Improvements](#6-architecture-improvements)
7. [Testing Setup](#7-testing-setup)
8. [Common Patterns](#8-common-patterns)

---

## 1. Security Fixes

### 🔒 **Secure Token Storage**

**Problem**: Currently using `GetStorage` for sensitive tokens
**Solution**: Implement `flutter_secure_storage`

#### Step 1: Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

#### Step 2: Create Secure Token Service
```dart
// lib/services/secure_token_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureTokenService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _accessTokenKey = 'secure_access_token';
  static const String _refreshTokenKey = 'secure_refresh_token';
  static const String _tokenExpiryKey = 'secure_token_expiry';

  // Store tokens securely
  static Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    try {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      
      if (expiresIn != null) {
        final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        await _secureStorage.write(
          key: _tokenExpiryKey, 
          value: expiryTime.toIso8601String()
        );
      }
    } catch (e) {
      print('Error storing tokens securely: $e');
      rethrow;
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      print('Error reading access token: $e');
      return null;
    }
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      print('Error reading refresh token: $e');
      return null;
    }
  }

  // Check if token is expired
  static Future<bool> isTokenExpired() async {
    try {
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryString == null) return true;

      final expiryTime = DateTime.parse(expiryString);
      return DateTime.now().isAfter(expiryTime);
    } catch (e) {
      print('Error checking token expiry: $e');
      return true;
    }
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
    } catch (e) {
      print('Error clearing tokens: $e');
      rethrow;
    }
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      final isExpired = await isTokenExpired();
      
      return accessToken != null && refreshToken != null && !isExpired;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }
}
```

#### Step 3: Update Existing Token Service
```dart
// lib/services/token_service.dart - Update existing methods
class TokenService {
  // Replace GetStorage calls with SecureTokenService
  static Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    await SecureTokenService.storeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  static Future<String?> getAccessToken() async {
    return await SecureTokenService.getAccessToken();
  }

  static Future<bool> isAuthenticated() async {
    return await SecureTokenService.isAuthenticated();
  }
  
  // ... update other methods similarly
}
```

### 🛡️ **JWT Token Validation**

```dart
// lib/utils/jwt_validator.dart
import 'dart:convert';
import 'dart:typed_data';

class JwtValidator {
  static bool isValidToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = _decodeBase64(parts[1]);
      final data = json.decode(payload);
      
      // Check expiration
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic>? getTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = _decodeBase64(parts[1]);
      return json.decode(payload) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string');
    }
    return utf8.decode(base64Url.decode(output));
  }
}
```

---

## 2. Performance Optimizations

### ⚡ **List Virtualization**

**Problem**: Large lists causing performance issues
**Solution**: Implement proper list virtualization

```dart
// lib/widgets/optimized_list_view.dart
import 'package:flutter/material.dart';

class OptimizedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final EdgeInsets? padding;

  const OptimizedListView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    this.loadingWidget,
    this.hasMore = false,
    this.onLoadMore,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: hasMore ? items.length + 1 : items.length,
      itemBuilder: (context, index) {
        // Load more trigger
        if (index == items.length) {
          if (hasMore && onLoadMore != null) {
            // Trigger load more
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore!();
            });
          }
          return loadingWidget ?? 
                 const Center(child: CircularProgressIndicator());
        }

        return itemBuilder(context, items[index], index);
      },
    );
  }
}

// Usage Example
class ProductListPage extends StatelessWidget {
  final List<Product> products;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const ProductListPage({
    Key? key,
    required this.products,
    required this.isLoading,
    required this.onLoadMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedListView<Product>(
      items: products,
      hasMore: !isLoading,
      onLoadMore: onLoadMore,
      itemBuilder: (context, product, index) {
        return ProductCard(product: product);
      },
      loadingWidget: const ShimmerLoader(),
    );
  }
}
```

### 🚀 **Memoization and Caching**

```dart
// lib/utils/memoization.dart
class Memoizer<T> {
  final Map<String, T> _cache = {};
  final Map<String, DateTime> _timestamps = {};
  final Duration cacheDuration;

  Memoizer({this.cacheDuration = const Duration(minutes: 5)});

  T memoize(String key, T Function() computation) {
    final now = DateTime.now();
    final timestamp = _timestamps[key];
    
    if (timestamp != null && 
        now.difference(timestamp) < cacheDuration &&
        _cache.containsKey(key)) {
      return _cache[key]!;
    }

    final result = computation();
    _cache[key] = result;
    _timestamps[key] = now;
    return result;
  }

  void clearCache() {
    _cache.clear();
    _timestamps.clear();
  }

  void remove(String key) {
    _cache.remove(key);
    _timestamps.remove(key);
  }
}

// Usage in controllers
class ProductController extends GetxController {
  final _memoizer = Memoizer<double>();

  double calculateTotal(List<Product> products) {
    return _memoizer.memoize(
      'total_${products.map((p) => p.id).join('_')}',
      () => products.fold(0.0, (sum, product) => sum + product.price),
    );
  }
}
```

### 🔄 **Background Processing**

```dart
// lib/utils/background_processor.dart
import 'dart:isolate';
import 'package:flutter/foundation.dart';

class BackgroundProcessor {
  // Process heavy computations in isolate
  static Future<List<ProcessedData>> processLargeDataset(
    List<RawData> rawData,
  ) async {
    if (rawData.length < 100) {
      // Process small datasets on main thread
      return _processData(rawData);
    }

    // Use isolate for heavy processing
    return await compute(_processDataInIsolate, rawData);
  }

  static List<ProcessedData> _processDataInIsolate(List<RawData> rawData) {
    return _processData(rawData);
  }

  static List<ProcessedData> _processData(List<RawData> rawData) {
    return rawData.map((raw) {
      // Heavy processing logic here
      return ProcessedData(
        id: raw.id,
        value: raw.value * 2, // Example calculation
        computed: DateTime.now(),
      );
    }).toList();
  }
}

// Usage in services
class DataService {
  Future<List<ProcessedData>> getProcessedData() async {
    final rawData = await _fetchRawData();
    return await BackgroundProcessor.processLargeDataset(rawData);
  }
}
```

---

## 3. Routing & Navigation

### 🛣️ **Route Guards and Middleware**

```dart
// lib/middleware/auth_middleware.dart
import 'package:get/get.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    
    if (!authController.isAuthenticated()) {
      return const RouteSettings(name: '/login');
    }
    return null;
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    print('🔒 Auth check for route: ${page?.name}');
    return super.onPageCalled(page);
  }
}

// lib/middleware/role_middleware.dart
class RoleMiddleware extends GetMiddleware {
  final List<String> allowedRoles;

  RoleMiddleware({required this.allowedRoles});

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    final userRole = authController.currentUser?.role;

    if (userRole == null || !allowedRoles.contains(userRole)) {
      return const RouteSettings(name: '/unauthorized');
    }
    return null;
  }
}
```

### 📱 **Enhanced Route Configuration**

```dart
// lib/routes/app_routes.dart
class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String orders = '/orders';
  static const String journeyPlans = '/journey-plans';
  static const String unauthorized = '/unauthorized';
  static const String notFound = '/404';

  static final routes = [
    // Public routes
    GetPage(
      name: login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),

    // Protected routes
    GetPage(
      name: home,
      page: () => const HomePage(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: profile,
      page: () => const ProfilePage(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Manager-only routes
    GetPage(
      name: '/admin/dashboard',
      page: () => const AdminDashboard(),
      middlewares: [
        AuthMiddleware(),
        RoleMiddleware(allowedRoles: ['manager', 'admin']),
      ],
    ),

    // Error routes
    GetPage(
      name: unauthorized,
      page: () => const UnauthorizedPage(),
    ),

    GetPage(
      name: notFound,
      page: () => const NotFoundPage(),
    ),
  ];

  // Unknown route handler
  static GetPage unknownRoute = GetPage(
    name: notFound,
    page: () => const NotFoundPage(),
  );
}

// lib/bindings/auth_binding.dart
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthController>(() => AuthController());
    Get.lazyPut<TokenService>(() => TokenService());
  }
}
```

### 🔗 **Navigation Helper**

```dart
// lib/utils/navigation_helper.dart
class NavigationHelper {
  // Safe navigation with error handling
  static Future<T?> navigateToPage<T>(
    String routeName, {
    dynamic arguments,
    bool clearStack = false,
  }) async {
    try {
      if (clearStack) {
        return await Get.offAllNamed<T>(routeName, arguments: arguments);
      }
      return await Get.toNamed<T>(routeName, arguments: arguments);
    } catch (e) {
      print('Navigation error: $e');
      // Fallback to safe route
      return await Get.toNamed<T>(AppRoutes.home);
    }
  }

  // Go back with validation
  static void goBack<T>([T? result]) {
    if (Get.routing.previous.isNotEmpty) {
      Get.back<T>(result: result);
    } else {
      // No previous route, go to home
      Get.offAllNamed(AppRoutes.home);
    }
  }

  // Logout and clear navigation stack
  static Future<void> logout() async {
    await Get.find<AuthController>().logout();
    Get.offAllNamed(AppRoutes.login);
  }
}
```

---

## 4. State Management

### 🎯 **Optimized Controller Structure**

```dart
// lib/controllers/base_controller.dart
abstract class BaseController extends GetxController {
  final _isLoading = false.obs;
  final _error = Rxn<String>();
  final List<StreamSubscription> _subscriptions = [];

  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  @override
  void onInit() {
    super.onInit();
    init();
  }

  @override
  void onClose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    dispose();
    super.onClose();
  }

  // Abstract methods for subclasses
  void init();
  void dispose();

  // Helper methods
  void setLoading(bool loading) => _isLoading.value = loading;
  void setError(String? error) => _error.value = error;
  void clearError() => _error.value = null;

  // Safe async operation wrapper
  Future<T?> safeAsyncOperation<T>(
    Future<T> Function() operation,
    {String? errorMessage}
  ) async {
    try {
      setLoading(true);
      clearError();
      final result = await operation();
      return result;
    } catch (e) {
      setError(errorMessage ?? 'An error occurred: $e');
      print('Error in ${runtimeType}: $e');
      return null;
    } finally {
      setLoading(false);
    }
  }
}

// lib/controllers/consolidated_order_controller.dart
class OrderController extends BaseController {
  final ApiService _apiService = Get.find<ApiService>();
  final HiveService _hiveService = Get.find<OrderHiveService>();

  final _orders = <Order>[].obs;
  final _cart = <CartItem>[].obs;
  final _selectedCategory = Rxn<Category>();

  List<Order> get orders => _orders;
  List<CartItem> get cart => _cart;
  Category? get selectedCategory => _selectedCategory.value;

  @override
  void init() {
    loadOrders();
    loadCart();
  }

  @override
  void dispose() {
    // Clean up resources
  }

  Future<void> loadOrders() async {
    await safeAsyncOperation(
      () => _loadOrdersFromAPI(),
      errorMessage: 'Failed to load orders',
    );
  }

  Future<void> addToCart(Product product, int quantity) async {
    await safeAsyncOperation(
      () => _addToCartOperation(product, quantity),
      errorMessage: 'Failed to add item to cart',
    );
  }

  // Private methods
  Future<void> _loadOrdersFromAPI() async {
    final orders = await _apiService.getOrders();
    _orders.assignAll(orders);
    
    // Cache locally
    await _hiveService.saveOrders(orders);
  }

  Future<void> _addToCartOperation(Product product, int quantity) async {
    final cartItem = CartItem(
      product: product,
      quantity: quantity,
      addedAt: DateTime.now(),
    );
    
    _cart.add(cartItem);
    await _hiveService.saveCartItem(cartItem);
  }
}
```

### 🔄 **State Synchronization**

```dart
// lib/services/state_sync_service.dart
class StateSyncService extends GetxService {
  final Map<String, StreamController> _controllers = {};
  
  // Create a stream for state synchronization
  Stream<T> createStateStream<T>(String key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<T>.broadcast();
    }
    return _controllers[key]!.stream.cast<T>();
  }

  // Emit state change
  void emitStateChange<T>(String key, T data) {
    final controller = _controllers[key];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }

  @override
  void onClose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    super.onClose();
  }
}

// Usage in controllers
class ProductController extends BaseController {
  final StateSyncService _syncService = Get.find<StateSyncService>();

  @override
  void init() {
    // Listen to product updates from other parts of the app
    _subscriptions.add(
      _syncService.createStateStream<Product>('product_updated')
        .listen((product) {
          _updateLocalProduct(product);
        })
    );
  }

  void updateProduct(Product product) {
    // Update local state
    _updateLocalProduct(product);
    
    // Notify other parts of the app
    _syncService.emitStateChange('product_updated', product);
  }
}
```

---

## 5. Code Quality & Linting

### ✅ **Enhanced Analysis Options**

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    # Re-enable important lints for better code quality
    use_build_context_synchronously: error
    unused_import: warning
    deprecated_member_use: warning
    library_private_types_in_public_api: warning
    prefer_const_constructors: info
    prefer_const_literals_to_create_immutables: info
    
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated_plugin_registrant.dart"

linter:
  rules:
    # Flutter specific
    use_build_context_synchronously: true
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true
    
    # Performance
    avoid_function_literals_in_foreach_calls: true
    prefer_collection_literals: true
    prefer_spread_collections: true
    
    # Style
    camel_case_types: true
    library_names: true
    file_names: true
    prefer_single_quotes: true
    
    # Error prevention
    close_sinks: true
    cancel_subscriptions: true
    avoid_returning_null_for_future: true
    unawaited_futures: true
```

### 🛠️ **Error Handling Utilities**

```dart
// lib/utils/error_handler.dart
class ErrorHandler {
  static void handleError(
    dynamic error, {
    String? context,
    bool showToUser = true,
    VoidCallback? onRetry,
  }) {
    String message = _getErrorMessage(error);
    
    // Log error
    print('❌ Error${context != null ? ' in $context' : ''}: $message');
    
    // Show to user if needed
    if (showToUser) {
      _showErrorToUser(message, onRetry: onRetry);
    }
  }

  static String _getErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return 'Network error. Please check your connection.';
    } else if (error is AuthException) {
      return 'Authentication failed. Please login again.';
    } else if (error is ValidationException) {
      return error.message;
    } else {
      return 'An unexpected error occurred.';
    }
  }

  static void _showErrorToUser(String message, {VoidCallback? onRetry}) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade800,
      mainButton: onRetry != null 
        ? TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          )
        : null,
    );
  }
}

// Custom exception classes
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}
```

### 📊 **Logging Utility**

```dart
// lib/utils/logger.dart
import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class Logger {
  static bool _isDebugMode = kDebugMode;
  
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag);
    if (error != null) {
      developer.log(
        'Error details: $error',
        name: tag ?? 'App',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _log(LogLevel level, String message, {String? tag}) {
    if (!_isDebugMode && level == LogLevel.debug) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    developer.log(
      '$timestamp $levelStr $tagStr$message',
      name: tag ?? 'App',
    );
  }
}

// Usage example
class ApiService {
  Future<List<Product>> getProducts() async {
    Logger.info('Fetching products', tag: 'API');
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      Logger.debug('Response: ${response.body}', tag: 'API');
      
      return parseProducts(response.body);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch products', 
        tag: 'API', 
        error: e, 
        stackTrace: stackTrace
      );
      rethrow;
    }
  }
}
```

---

## 6. Architecture Improvements

### 🏗️ **Feature-Based Structure**

```
lib/
├── app/                          # App configuration
│   ├── bindings/
│   ├── routes/
│   └── theme/
├── core/                         # Core utilities
│   ├── constants/
│   ├── extensions/
│   ├── utils/
│   └── services/
├── features/                     # Feature modules
│   ├── authentication/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── pages/
│   │   ├── services/
│   │   └── widgets/
│   ├── orders/
│   ├── journey_plans/
│   └── profile/
└── shared/                       # Shared components
    ├── widgets/
    ├── models/
    └── services/
```

### 🎨 **Widget Architecture**

```dart
// lib/shared/widgets/base_page.dart
abstract class BasePage extends StatelessWidget {
  const BasePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: SafeArea(
        child: buildBody(context),
      ),
      floatingActionButton: buildFAB(context),
      bottomNavigationBar: buildBottomNav(context),
    );
  }

  // Abstract methods for subclasses
  PreferredSizeWidget? buildAppBar(BuildContext context) => null;
  Widget buildBody(BuildContext context);
  Widget? buildFAB(BuildContext context) => null;
  Widget? buildBottomNav(BuildContext context) => null;
}

// lib/shared/widgets/loading_overlay.dart
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingText;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (loadingText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingText!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

---

## 7. Testing Setup

### 🧪 **Test Structure**

```yaml
# pubspec.yaml - Add test dependencies
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.8
  integration_test:
    sdk: flutter
```

### 🧪 **Unit Test Examples**

```dart
// test/controllers/auth_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/services/api_service.dart';

@GenerateMocks([ApiService])
import 'auth_controller_test.mocks.dart';

void main() {
  group('AuthController Tests', () {
    late AuthController authController;
    late MockApiService mockApiService;

    setUp(() {
      mockApiService = MockApiService();
      authController = AuthController();
      // Inject mock service
    });

    tearDown(() {
      authController.dispose();
    });

    test('should login successfully with valid credentials', () async {
      // Arrange
      const phoneNumber = '1234567890';
      const password = 'password123';
      final mockResponse = {
        'success': true,
        'salesRep': {'id': 1, 'name': 'Test User'},
        'accessToken': 'mock_token',
        'refreshToken': 'mock_refresh_token',
      };

      when(mockApiService.login(phoneNumber, password))
          .thenAnswer((_) async => mockResponse);

      // Act
      await authController.login(phoneNumber, password);

      // Assert
      expect(authController.isLoggedIn.value, true);
      expect(authController.currentUser, isNotNull);
      verify(mockApiService.login(phoneNumber, password)).called(1);
    });

    test('should handle login failure', () async {
      // Arrange
      const phoneNumber = '1234567890';
      const password = 'wrong_password';

      when(mockApiService.login(phoneNumber, password))
          .thenThrow(Exception('Invalid credentials'));

      // Act & Assert
      expect(
        () => authController.login(phoneNumber, password),
        throwsException,
      );
    });
  });
}
```

### 🧪 **Widget Test Example**

```dart
// test/widgets/product_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woosh/widgets/product_card.dart';
import 'package:woosh/models/product_model.dart';

void main() {
  group('ProductCard Widget Tests', () {
    late Product testProduct;

    setUp(() {
      testProduct = Product(
        id: 1,
        name: 'Test Product',
        price: 99.99,
        imageUrl: 'https://example.com/image.jpg',
      );
    });

    testWidgets('should display product information', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(product: testProduct),
          ),
        ),
      );

      // Assert
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('\$99.99'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      // Arrange
      bool wasTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: testProduct,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(ProductCard));
      await tester.pump();

      // Assert
      expect(wasTapped, true);
    });
  });
}
```

---

## 8. Common Patterns

### 🎯 **API Response Handling**

```dart
// lib/models/api_response.dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory ApiResponse.success(T data, {String? message}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error(String message, {String? errorCode}) {
    return ApiResponse(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      message: json['message'],
      errorCode: json['error_code'],
    );
  }
}

// Usage in services
class ProductService {
  Future<ApiResponse<List<Product>>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      final json = jsonDecode(response.body);
      
      return ApiResponse.fromJson(
        json,
        (data) => (data as List)
            .map((item) => Product.fromJson(item))
            .toList(),
      );
    } catch (e) {
      return ApiResponse.error('Failed to load products');
    }
  }
}
```

### 🔄 **Repository Pattern**

```dart
// lib/repositories/product_repository.dart
abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<Product?> getProduct(int id);
  Future<bool> saveProduct(Product product);
  Future<bool> deleteProduct(int id);
}

class ProductRepositoryImpl implements ProductRepository {
  final ApiService _apiService;
  final ProductHiveService _hiveService;
  final ConnectivityService _connectivityService;

  ProductRepositoryImpl({
    required ApiService apiService,
    required ProductHiveService hiveService,
    required ConnectivityService connectivityService,
  }) : _apiService = apiService,
       _hiveService = hiveService,
       _connectivityService = connectivityService;

  @override
  Future<List<Product>> getProducts() async {
    if (await _connectivityService.isConnected()) {
      try {
        final products = await _apiService.getProducts();
        await _hiveService.saveProducts(products);
        return products;
      } catch (e) {
        // Fallback to local data
        return await _hiveService.getProducts();
      }
    } else {
      return await _hiveService.getProducts();
    }
  }

  @override
  Future<Product?> getProduct(int id) async {
    // Try local first for speed
    final localProduct = await _hiveService.getProduct(id);
    if (localProduct != null) {
      return localProduct;
    }

    // Fetch from API if not found locally
    if (await _connectivityService.isConnected()) {
      try {
        final product = await _apiService.getProduct(id);
        if (product != null) {
          await _hiveService.saveProduct(product);
        }
        return product;
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // ... implement other methods
}
```

### 🎨 **Theme Management**

```dart
// lib/core/theme/app_theme.dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      cardTheme: _cardTheme,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      appBarTheme: _appBarTheme.copyWith(
        backgroundColor: _darkColorScheme.surface,
        foregroundColor: _darkColorScheme.onSurface,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      cardTheme: _cardTheme,
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFAE8625),
    onPrimary: Colors.white,
    secondary: Color(0xFFEDC967),
    onSecondary: Colors.black,
    surface: Color(0xFFF4EBD0),
    onSurface: Colors.black,
    background: Colors.white,
    onBackground: Colors.black,
    error: Colors.red,
    onError: Colors.white,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFEDC967),
    onPrimary: Colors.black,
    secondary: Color(0xFFAE8625),
    onSecondary: Colors.white,
    surface: Color(0xFF2C2C2C),
    onSurface: Colors.white,
    background: Color(0xFF1E1E1E),
    onBackground: Colors.white,
    error: Colors.redAccent,
    onError: Colors.white,
  );

  // Define component themes...
  static const AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme = 
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  // ... other theme components
}
```

---

## Implementation Checklist

### 🔒 **Security (Priority 1)**
- [ ] Replace GetStorage with flutter_secure_storage for tokens
- [ ] Implement JWT validation
- [ ] Add token rotation mechanism
- [ ] Audit all storage access points

### ⚡ **Performance (Priority 2)**
- [ ] Implement list virtualization
- [ ] Add memoization for expensive calculations
- [ ] Use compute() for background processing
- [ ] Optimize image loading with proper caching

### 🛣️ **Navigation (Priority 3)**
- [ ] Add authentication middleware
- [ ] Implement role-based route guards
- [ ] Add error route handling
- [ ] Create navigation helper utilities

### 🎯 **State Management (Priority 4)**
- [ ] Consolidate related controllers
- [ ] Implement proper disposal patterns
- [ ] Add state synchronization service
- [ ] Create base controller class

### ✅ **Code Quality (Priority 5)**
- [ ] Update analysis_options.yaml
- [ ] Implement error handling utilities
- [ ] Add comprehensive logging
- [ ] Remove debug prints from production

### 🏗️ **Architecture (Long-term)**
- [ ] Refactor to feature-based structure
- [ ] Implement repository pattern
- [ ] Add comprehensive testing
- [ ] Create CI/CD pipeline

---

*This reference guide provides practical implementations for all major issues identified in the Woosh app audit. Follow the priorities and implement changes incrementally to maintain app stability.*