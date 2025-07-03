import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/controllers/auth_controller.dart';
import 'package:glamour_queen/services/session_service.dart';
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

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
  @override
  Widget build(BuildContext context) {
    // Just wrap the child, no inactivity monitoring
    return widget.child;
  }
}

