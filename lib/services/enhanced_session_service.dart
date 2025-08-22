import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/auth_controller.dart';

class EnhancedSessionService extends GetxService {
  static EnhancedSessionService get instance => Get.find<EnhancedSessionService>();

  Timer? _sessionCheckTimer;
  Timer? _warningTimer;
  bool _warningShown = false;
  bool _isSessionActive = true;

  // Session configuration
  static const int sessionTimeoutMinutes = 30; // 30 minutes of inactivity
  static const int warningBeforeTimeoutMinutes = 5; // Show warning 5 minutes before timeout
  static const int sessionCheckIntervalSeconds = 60; // Check every minute

  DateTime _lastActivity = DateTime.now();
  
  @override
  Future<void> onInit() async {
    super.onInit();
    _startSessionMonitoring();
    _resetActivity(); // Reset activity on service init
  }

  @override
  void onClose() {
    _sessionCheckTimer?.cancel();
    _warningTimer?.cancel();
    super.onClose();
  }

  /// Start monitoring session activity
  void _startSessionMonitoring() {
    _sessionCheckTimer = Timer.periodic(
      Duration(seconds: sessionCheckIntervalSeconds),
      (_) => _checkSessionStatus(),
    );
  }

  /// Reset user activity timestamp
  void resetActivity() {
    _lastActivity = DateTime.now();
    _warningShown = false;
    _warningTimer?.cancel();
    
    // If session was inactive, reactivate it
    if (!_isSessionActive) {
      _isSessionActive = true;
      print('📱 Session reactivated due to user activity');
    }
  }

  /// Check current session status
  void _checkSessionStatus() {
    if (!TokenService.isAuthenticated()) {
      _stopSessionMonitoring();
      return;
    }

    final timeSinceLastActivity = DateTime.now().difference(_lastActivity);
    final minutesSinceActivity = timeSinceLastActivity.inMinutes;

    // Check if warning should be shown
    if (minutesSinceActivity >= (sessionTimeoutMinutes - warningBeforeTimeoutMinutes) && 
        !_warningShown && 
        _isSessionActive) {
      _showSessionWarning();
    }

    // Check if session should timeout
    if (minutesSinceActivity >= sessionTimeoutMinutes && _isSessionActive) {
      _handleSessionTimeout();
    }
  }

  /// Show session timeout warning
  void _showSessionWarning() {
    _warningShown = true;
    
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Session Timeout Warning'),
          ],
        ),
        content: Text(
          'Your session will expire in $warningBeforeTimeoutMinutes minutes due to inactivity. '
          'Tap "Stay Logged In" to continue your session.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _handleSessionTimeout();
            },
            child: Text('Logout Now', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              resetActivity(); // Reset activity to extend session
              Get.snackbar(
                'Session Extended',
                'Your session has been extended.',
                snackPosition: SnackPosition.TOP,
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: Duration(seconds: 2),
              );
            },
            child: Text('Stay Logged In'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    // Auto-timeout if user doesn't respond within warning period
    _warningTimer = Timer(
      Duration(minutes: warningBeforeTimeoutMinutes),
      () => _handleSessionTimeout(),
    );
  }

  /// Handle session timeout
  void _handleSessionTimeout() async {
    if (!_isSessionActive) return; // Already handled
    
    _isSessionActive = false;
    _stopSessionMonitoring();
    
    Get.back(); // Close any open dialogs
    
    // Show timeout message
    Get.snackbar(
      'Session Expired',
      'Your session has expired due to inactivity. Please log in again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 4),
      isDismissible: false,
    );

    // Perform logout
    try {
      await ApiService.logout();
    } catch (e) {
      print('Error during automatic logout: $e');
    }
    
    // Navigate to login
    Get.offAllNamed('/login');
  }

  /// Stop session monitoring
  void _stopSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _warningTimer?.cancel();
    _sessionCheckTimer = null;
    _warningTimer = null;
  }

  /// Get time remaining until session expires
  Duration getTimeUntilExpiry() {
    final timeSinceLastActivity = DateTime.now().difference(_lastActivity);
    final timeUntilExpiry = Duration(minutes: sessionTimeoutMinutes) - timeSinceLastActivity;
    return timeUntilExpiry.isNegative ? Duration.zero : timeUntilExpiry;
  }

  /// Check if session is about to expire
  bool isSessionExpiringSoon() {
    final timeUntilExpiry = getTimeUntilExpiry();
    return timeUntilExpiry.inMinutes <= warningBeforeTimeoutMinutes;
  }

  /// Get session status info
  Map<String, dynamic> getSessionInfo() {
    return {
      'isActive': _isSessionActive,
      'lastActivity': _lastActivity,
      'timeUntilExpiry': getTimeUntilExpiry(),
      'isExpiringSoon': isSessionExpiringSoon(),
      'warningShown': _warningShown,
    };
  }

  /// Force refresh session (useful for critical operations)
  Future<bool> forceRefreshSession() async {
    try {
      final refreshed = await ApiService.refreshAccessToken();
      if (refreshed) {
        resetActivity();
        return true;
      }
      return false;
    } catch (e) {
      print('Error forcing session refresh: $e');
      return false;
    }
  }
}