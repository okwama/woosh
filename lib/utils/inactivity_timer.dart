import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:woosh/controllers/auth_controller.dart';

class InactivityTimer extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final bool enableLogging;

  const InactivityTimer({
    super.key,
    required this.child,
    this.timeout = const Duration(hours: 2),
    this.enableLogging = false,
  });

  @override
  State<InactivityTimer> createState() => _InactivityTimerState();
}

class _InactivityTimerState extends State<InactivityTimer> {
  Timer? _timer;
  final AuthController _authController = Get.find<AuthController>();
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _setupTimer();

    // Listen for auth state changes to conditionally activate timer
    ever(_authController.isLoggedIn, (isLoggedIn) {
      if (isLoggedIn) {
        _setupTimer();
      } else {
        _cancelTimer();
      }
    });
  }

  void _setupTimer() {
    // Only setup timer if user is logged in
    if (_authController.isLoggedIn.value) {
      _resetTimer();
      if (widget.enableLogging) {
        print('InactivityTimer: Timer started');
      }
    }
  }

  void _cancelTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      if (widget.enableLogging) {
        print('InactivityTimer: Timer canceled');
      }
    }
  }

  void _resetTimer() {
    _cancelTimer();
    _timer = Timer(widget.timeout, _onInactivityTimeout);
    if (widget.enableLogging) {
      print(
          'InactivityTimer: Timer reset - will timeout in ${widget.timeout.inMinutes} minutes');
    }
  }

  void _onInactivityTimeout() {
    // Only logout if user is currently logged in
    if (_authController.isLoggedIn.value) {
      if (widget.enableLogging) {
        print('InactivityTimer: Timeout reached - logging out user');
      }
      _authController.logout();
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only enable activity monitoring when user is logged in
    return Obx(() {
      if (_authController.isLoggedIn.value) {
        return RawKeyboardListener(
          focusNode: _focusNode!,
          onKey: (_) => _resetTimer(),
          child: Listener(
            onPointerDown: (_) => _resetTimer(),
            onPointerMove: (_) => _resetTimer(),
            onPointerUp: (_) => _resetTimer(),
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
        );
      } else {
        // If not logged in, just return the child without activity monitoring
        return widget.child;
      }
    });
  }
}
