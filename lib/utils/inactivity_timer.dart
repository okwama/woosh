import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/services/session_service.dart';

class InactivityTimer extends StatefulWidget {
  final Widget child;
  final bool enableLogging;

  const InactivityTimer({
    super.key,
    required this.child,
    this.enableLogging = false,
  });

  @override
  State<InactivityTimer> createState() => _InactivityTimerState();
}

class _InactivityTimerState extends State<InactivityTimer> {
  Timer? _dailyCheckTimer;
  final AuthController _authController = Get.find<AuthController>();
  final GetStorage _box = GetStorage();

  bool get _isAfter9PM {
    final now = DateTime.now();
    return now.hour >= 21; // 9 PM
  }

  @override
  void initState() {
    super.initState();
    _setupDailyCheckTimer();

    // Listen for auth state changes to conditionally activate timer
    ever(_authController.isLoggedIn, (isLoggedIn) {
      if (isLoggedIn) {
        _setupDailyCheckTimer();
        // Check immediately if it's after 9 PM when user logs in
        if (_isAfter9PM) {
          _onDailyLogoutTime();
        }
      } else {
        _cancelTimer();
      }
    });
  }

  void _setupDailyCheckTimer() {
    // Cancel any existing timer
    _cancelTimer();

    // Only set up if user is logged in
    if (!_authController.isLoggedIn.value) return;

    // Calculate time until next 9 PM
    final now = DateTime.now();
    DateTime nextCheck;

    if (now.hour < 21) {
      // If before 9 PM today, check at 9 PM today
      nextCheck = DateTime(now.year, now.month, now.day, 21);
    } else {
      // If after 9 PM, check at 9 PM tomorrow
      nextCheck = DateTime(now.year, now.month, now.day + 1, 21);
    }

    final durationUntilNextCheck = nextCheck.difference(now);

    if (widget.enableLogging) {
      print(
          'Next daily check at: $nextCheck (in ${durationUntilNextCheck.inMinutes} minutes)');
    }

    _dailyCheckTimer = Timer(durationUntilNextCheck, _onDailyLogoutTime);
  }

  Future<void> _onDailyLogoutTime() async {
    if (widget.enableLogging) {
      print('InactivityTimer: 9 PM reached - logging out user');
    }

    try {
      // Get the current user ID
      final userId = _box.read<String>('userId');

      if (userId != null) {
        // Record the logout in the session service
        await SessionService.recordLogout(userId);

        // Update local session state
        await _box.write('isSessionActive', false);

        if (widget.enableLogging) {
          print('Successfully recorded logout in session service');
        }
      }

      // Log out the user from the app
      await _authController.logout();
    } catch (e) {
      if (widget.enableLogging) {
        print('Error during session logout: $e');
      }
      // Even if session logout fails, still log the user out locally
      await _authController.logout();
    }

    // Schedule next check for tomorrow
    _setupDailyCheckTimer();
  }

  void _cancelTimer() {
    _dailyCheckTimer?.cancel();
    _dailyCheckTimer = null;

    if (widget.enableLogging) {
      print('InactivityTimer: Daily check timer canceled');
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Just wrap the child, no need for activity monitoring
    return widget.child;
  }
}
