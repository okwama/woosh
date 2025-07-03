import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/utils/error_handler.dart';

/// Safe error handler utility to ensure no raw errors are shown to users
class SafeErrorHandler {
  /// Safe SnackBar that filters raw errors
  static void showSnackBar(
    BuildContext context,
    dynamic error, {
    Color? backgroundColor,
    Duration? duration,
    SnackBarAction? action,
    bool isSuccess = false,
  }) {
    String message;
    Color bgColor;

    if (isSuccess) {
      // For success messages, show as-is
      message = error.toString();
      bgColor = backgroundColor ?? Colors.green.shade600;
    } else {
      // For errors, filter through the global error handler
      message = GlobalErrorHandler.getUserFriendlyMessage(error);
      bgColor = backgroundColor ?? Colors.red.shade600;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: action,
      ),
    );
  }

  /// Safe Get.snackbar that filters raw errors
  static void showGetSnackBar(
    dynamic error, {
    String? title,
    Color? backgroundColor,
    Duration? duration,
    bool isSuccess = false,
    VoidCallback? onRetry,
  }) {
    String message;
    String snackTitle;
    Color bgColor;

    if (isSuccess) {
      // For success messages, show as-is
      message = error.toString();
      snackTitle = title ?? 'Success';
      bgColor = backgroundColor ?? Colors.green.shade600;
    } else {
      // For errors, filter through the global error handler
      message = GlobalErrorHandler.getUserFriendlyMessage(error);
      snackTitle = title ?? 'Oops!';
      bgColor = backgroundColor ?? Colors.red.shade600;
    }

    Get.snackbar(
      snackTitle,
      message,
      backgroundColor: bgColor,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error_outline,
        color: Colors.white,
        size: 20,
      ),
      mainButton: onRetry != null
          ? TextButton(
              onPressed: () {
                Get.back();
                onRetry();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  /// Safe dialog that filters raw errors
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final message = GlobalErrorHandler.getUserFriendlyMessage(error);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(title ?? 'Something went wrong'),
          ],
        ),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Safe success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    showSnackBar(
      context,
      message,
      isSuccess: true,
      duration: duration,
    );
  }

  /// Safe success with Get.snackbar
  static void showGetSuccess(
    String message, {
    String? title,
    Duration? duration,
  }) {
    showGetSnackBar(
      message,
      title: title ?? 'Success',
      isSuccess: true,
      duration: duration,
    );
  }

  /// Log error safely for debugging
  static void logError(dynamic error, {String? context}) {
    GlobalErrorHandler.logError(error, context: context);
  }

  /// Check if error should be retried
  static bool shouldRetry(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('socket');
  }

  /// Get retry delay based on error type
  static Duration getRetryDelay(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('rate limit') || errorString.contains('429')) {
      return const Duration(seconds: 30);
    }
    if (errorString.contains('server') || errorString.contains('5')) {
      return const Duration(seconds: 10);
    }
    return const Duration(seconds: 3);
  }
}

/// Extension to make error handling even easier
extension SafeErrorExtension on dynamic {
  /// Convert any error to user-friendly message
  String toUserFriendlyMessage() {
    return GlobalErrorHandler.getUserFriendlyMessage(this);
  }

  /// Check if this is a network error
  bool get isNetworkError {
    final errorString = toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout');
  }

  /// Check if this is a server error
  bool get isServerError {
    final errorString = toString().toLowerCase();
    return errorString.contains('500') ||
        errorString.contains('501') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }
}
