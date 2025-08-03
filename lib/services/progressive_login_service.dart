import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/services/offline_sync_service.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:get_storage/get_storage.dart';

enum LoginStatus {
  success,
  offline,
  failed,
  pending,
}

class ProgressiveLoginResult {
  final LoginStatus status;
  final String message;
  final Map<String, dynamic>? data;
  final bool requiresSync;

  ProgressiveLoginResult({
    required this.status,
    required this.message,
    this.data,
    this.requiresSync = false,
  });

  bool get isSuccess => status == LoginStatus.success;
  bool get isOffline => status == LoginStatus.offline;
  bool get isFailed => status == LoginStatus.failed;
  bool get isPending => status == LoginStatus.pending;
}

class ProgressiveLoginService extends GetxService {
  static ProgressiveLoginService get instance =>
      Get.find<ProgressiveLoginService>();

  final _isOnline = true.obs;
  final _isSyncing = false.obs;
  final _pendingLogins = <Map<String, dynamic>>[].obs;

  bool get isOnline => _isOnline.value;
  bool get isSyncing => _isSyncing.value;
  List<Map<String, dynamic>> get pendingLogins => _pendingLogins;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeConnectivity();
    await _loadPendingLogins();
  }

  Future<void> _initializeConnectivity() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline.value = connectivityResult != ConnectivityResult.none;

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
          final wasOffline = !_isOnline.value;
          _isOnline.value = result != ConnectivityResult.none;

          // If we just came back online, sync pending logins
          if (wasOffline && _isOnline.value && _pendingLogins.isNotEmpty) {
            _syncPendingLogins();
          }
        } as void Function(List<ConnectivityResult> event)?);
  }

  /// Main progressive login method
  Future<ProgressiveLoginResult> login(
      String phoneNumber, String password) async {
    try {
      // Step 1: Quick local validation
      final localValidation =
          _validateCredentialsLocally(phoneNumber, password);
      if (!localValidation.isValid) {
        return ProgressiveLoginResult(
          status: LoginStatus.failed,
          message: localValidation.errorMessage ?? 'Validation failed',
        );
      }

      // Step 2: Try online login if network is available
      if (_isOnline.value) {
        try {
          final onlineResult = await _attemptOnlineLogin(phoneNumber, password);
          if (onlineResult.isSuccess) {
            return ProgressiveLoginResult(
              status: LoginStatus.success,
              message: 'Login successful',
              data: onlineResult.data,
            );
          }
        } catch (e) {
          // Online login failed, fall back to offline mode
          print('Online login failed, falling back to offline mode: $e');
        }
      }

      // Step 3: Create offline session
      return await _createOfflineSession(phoneNumber, password);
    } catch (e) {
      return ProgressiveLoginResult(
        status: LoginStatus.failed,
        message: 'Login failed: ${e.toString()}',
      );
    }
  }

  /// Local credential validation
  LocalValidationResult _validateCredentialsLocally(
      String phoneNumber, String password) {
    // Phone number validation
    if (phoneNumber.isEmpty) {
      return LocalValidationResult(
        isValid: false,
        errorMessage: 'Phone number is required',
      );
    }

    if (!RegExp(r'^\d{10,12}$').hasMatch(phoneNumber)) {
      return LocalValidationResult(
        isValid: false,
        errorMessage: 'Enter a valid phone number',
      );
    }

    // Password validation
    if (password.isEmpty) {
      return LocalValidationResult(
        isValid: false,
        errorMessage: 'Password is required',
      );
    }

    if (password.length < 6) {
      return LocalValidationResult(
        isValid: false,
        errorMessage: 'Password must be at least 6 characters',
      );
    }

    return LocalValidationResult(isValid: true);
  }

  /// Attempt online login
  Future<ProgressiveLoginResult> _attemptOnlineLogin(
      String phoneNumber, String password) async {
    try {
      final result = await ApiService().login(phoneNumber, password);

      if (result['success'] == true) {
        // Store successful login data
        await _storeSuccessfulLogin(phoneNumber, result);

        return ProgressiveLoginResult(
          status: LoginStatus.success,
          message: 'Login successful',
          data: result,
        );
      } else {
        return ProgressiveLoginResult(
          status: LoginStatus.failed,
          message: result['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create offline session
  Future<ProgressiveLoginResult> _createOfflineSession(
      String phoneNumber, String password) async {
    try {
      // Create offline session data
      final offlineSession = {
        'phoneNumber': phoneNumber,
        'password': password, // Note: In production, consider encryption
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending',
        'attempts': 0,
      };

      // Store pending login
      await _storePendingLogin(offlineSession);

      // Create temporary offline access
      final tempUserData = await _createTemporaryUserData(phoneNumber);

      return ProgressiveLoginResult(
        status: LoginStatus.offline,
        message: 'Login successful',
        data: tempUserData,
        requiresSync: true,
      );
    } catch (e) {
      return ProgressiveLoginResult(
        status: LoginStatus.failed,
        message: 'Failed to create offline session: ${e.toString()}',
      );
    }
  }

  /// Create temporary user data for offline access
  Future<Map<String, dynamic>> _createTemporaryUserData(
      String phoneNumber) async {
    // Get cached user data if available
    final box = GetStorage();
    final cachedUser = box.read('salesRep');

    if (cachedUser != null && cachedUser['phoneNumber'] == phoneNumber) {
      return {
        'salesRep': cachedUser,
        'accessToken': 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
        'refreshToken':
            'offline_refresh_${DateTime.now().millisecondsSinceEpoch}',
        'expiresIn': 8 * 60 * 60, // 8 hours
        'isOffline': true,
      };
    }

    // Create minimal offline user data
    return {
      'salesRep': {
        'id': 0,
        'phoneNumber': phoneNumber,
        'name': 'Offline User',
        'role': 'USER',
        'isOffline': true,
      },
      'accessToken': 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
      'refreshToken':
          'offline_refresh_${DateTime.now().millisecondsSinceEpoch}',
      'expiresIn': 8 * 60 * 60,
      'isOffline': true,
    };
  }

  /// Store successful login data
  Future<void> _storeSuccessfulLogin(
      String phoneNumber, Map<String, dynamic> loginData) async {
    final box = GetStorage();

    // Store login history
    final loginHistory = box.read('loginHistory') ?? [];
    loginHistory.add({
      'phoneNumber': phoneNumber,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'success',
      'isOnline': true,
    });

    // Keep only last 10 logins
    if (loginHistory.length > 10) {
      loginHistory.removeRange(0, loginHistory.length - 10);
    }

    await box.write('loginHistory', loginHistory);
  }

  /// Store pending login for later sync
  Future<void> _storePendingLogin(Map<String, dynamic> offlineSession) async {
    _pendingLogins.add(offlineSession);
    await _savePendingLogins();
  }

  /// Load pending logins from storage
  Future<void> _loadPendingLogins() async {
    final box = GetStorage();
    final saved = box.read('pendingLogins') ?? [];
    _pendingLogins.value = List<Map<String, dynamic>>.from(saved);
  }

  /// Save pending logins to storage
  Future<void> _savePendingLogins() async {
    final box = GetStorage();
    await box.write('pendingLogins', _pendingLogins);
  }

  /// Sync pending logins when online
  Future<void> _syncPendingLogins() async {
    if (_isSyncing.value || _pendingLogins.isEmpty) return;

    _isSyncing.value = true;

    try {
      final loginsToSync = List<Map<String, dynamic>>.from(_pendingLogins);

      for (final loginData in loginsToSync) {
        try {
          final result = await _attemptOnlineLogin(
            loginData['phoneNumber'],
            loginData['password'],
          );

          if (result.isSuccess) {
            // Remove successful login from pending
            _pendingLogins.removeWhere((login) =>
                login['phoneNumber'] == loginData['phoneNumber'] &&
                login['timestamp'] == loginData['timestamp']);
          } else {
            // Increment attempts
            final index = _pendingLogins.indexWhere((login) =>
                login['phoneNumber'] == loginData['phoneNumber'] &&
                login['timestamp'] == loginData['timestamp']);

            if (index != -1) {
              _pendingLogins[index]['attempts'] =
                  (_pendingLogins[index]['attempts'] ?? 0) + 1;

              // Remove if too many attempts
              if (_pendingLogins[index]['attempts'] >= 3) {
                _pendingLogins.removeAt(index);
              }
            }
          }
        } catch (e) {
          print('Failed to sync login: $e');
        }
      }

      await _savePendingLogins();
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Get sync status for UI
  String getSyncStatus() {
    if (_isSyncing.value) {
      return 'Syncing login data...';
    } else if (_pendingLogins.isNotEmpty && _isOnline.value) {
      return '${_pendingLogins.length} login(s) pending sync';
    } else if (_pendingLogins.isNotEmpty && !_isOnline.value) {
      return '${_pendingLogins.length} login(s) saved offline';
    } else {
      return 'All logins synced';
    }
  }

  /// Clear all pending logins
  Future<void> clearPendingLogins() async {
    _pendingLogins.clear();
    await _savePendingLogins();
  }

  /// Check if user has offline access
  bool hasOfflineAccess() {
    final box = GetStorage();
    final userData = box.read('salesRep');
    return userData != null && userData['isOffline'] == true;
  }

  /// Convert offline user to online user
  Future<void> convertOfflineToOnline(Map<String, dynamic> onlineData) async {
    final box = GetStorage();
    final currentUser = box.read('salesRep');

    if (currentUser != null && currentUser['isOffline'] == true) {
      // Update with real online data
      await box.write('salesRep', onlineData['salesRep']);

      // Store tokens
      await TokenService.storeTokens(
        accessToken: onlineData['accessToken'],
        refreshToken: onlineData['refreshToken'],
        expiresIn: onlineData['expiresIn'],
      );
    }
  }
}

class LocalValidationResult {
  final bool isValid;
  final String? errorMessage;

  LocalValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
