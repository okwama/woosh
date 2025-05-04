import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/auth_controller.dart';

class NoConnectionPage extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const NoConnectionPage({
    super.key,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Icon(
                  Icons.signal_wifi_off_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),

                // Error Title
                Text(
                  'No Internet Connection',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Error Message
                Text(
                  message ??
                      'Please check your internet connection and try again.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onBackground
                            .withOpacity(0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Retry Button
                ElevatedButton.icon(
                  onPressed: () {
                    if (onRetry != null) {
                      onRetry!();
                    } else {
                      // Default retry action
                      final authController = Get.find<AuthController>();
                      if (authController.isLoggedIn.value) {
                        Get.offAllNamed('/home');
                      } else {
                        Get.offAllNamed('/login');
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
