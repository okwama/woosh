import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/services/offline_toast_service.dart';

class GlobalErrorHandler {
  // Flag to prevent multiple error dialogs
  static bool _isShowingError = false;

  /// Main error handler - filters all errors and shows user-friendly messages
  static void handleApiError(dynamic error, {bool showToast = true}) {
    print('Global error handler: $error');

    // Never show raw errors to users
    final userFriendlyMessage = getUserFriendlyMessage(error);
    final errorType = _getErrorType(error);

    switch (errorType) {
      case ErrorType.authentication:
        _handleAuthError(error);
        break;
      case ErrorType.network:
        if (showToast) {
          OfflineToastService.show(
            message: userFriendlyMessage,
            duration: const Duration(seconds: 4),
          );
        }
        break;
      case ErrorType.server:
      case ErrorType.client:
      case ErrorType.validation:
      case ErrorType.unknown:
        if (showToast) {
          _showUserFriendlyError(userFriendlyMessage);
        }
        break;
    }
  }

  /// Get user-friendly message based on error
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Timeout errors (check before network errors)
    if (_isTimeoutError(errorString)) {
      return "The request is taking too long. Please try again.";
    }

    // Validation errors (check before client errors)
    if (_isValidationError(errorString)) {
      return "Please check your input and try again.";
    }

    // Network errors
    if (_isNetworkError(errorString)) {
      return "Please check your internet connection and try again.";
    }

    // Server errors (5xx)
    if (_isServerError(errorString)) {
      return "Our servers are temporarily unavailable. Please try again later.";
    }

    // Client errors (4xx)
    if (_isClientError(errorString)) {
      if (errorString.contains('401') || errorString.contains('unauthorized')) {
        return "Your session has expired. Please log in again.";
      }
      if (errorString.contains('403') || errorString.contains('forbidden')) {
        return "You don't have permission to perform this action.";
      }
      if (errorString.contains('404') || errorString.contains('not found')) {
        return "The requested information could not be found.";
      }
      if (errorString.contains('429') || errorString.contains('rate limit')) {
        return "Too many requests. Please wait a moment and try again.";
      }
      return "There was an issue with your request. Please try again.";
    }

    // Default fallback
    return "Something went wrong. Please try again.";
  }

  /// Determine error type for handling
  static ErrorType _getErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (_isAuthError(errorString)) {
      return ErrorType.authentication;
    }
    if (_isTimeoutError(errorString)) {
      return ErrorType.network; // Treat timeouts as network errors
    }
    if (_isValidationError(errorString)) {
      return ErrorType.validation;
    }
    if (_isNetworkError(errorString)) {
      return ErrorType.network;
    }
    if (_isServerError(errorString)) {
      return ErrorType.server;
    }
    if (_isClientError(errorString)) {
      return ErrorType.client;
    }

    return ErrorType.unknown;
  }

  /// Check if error is network-related
  static bool _isNetworkError(String errorString) {
    return errorString.contains('socketexception') ||
        errorString.contains('connection timeout') ||
        errorString.contains('network error') ||
        errorString.contains('connection refused') ||
        errorString.contains('no internet') ||
        errorString.contains('xmlhttprequest error') ||
        errorString.contains('failed to connect') ||
        errorString.contains('failed to fetch') ||
        errorString.contains('clientexception') ||
        errorString.contains('connection failed');
  }

  /// Check if error is server-related (5xx)
  static bool _isServerError(String errorString) {
    return errorString.contains('500') ||
        errorString.contains('501') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('505') ||
        errorString.contains('internal server error') ||
        errorString.contains('bad gateway') ||
        errorString.contains('service unavailable') ||
        errorString.contains('gateway timeout');
  }

  /// Check if error is client-related (4xx)
  static bool _isClientError(String errorString) {
    return errorString.contains('400') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('404') ||
        errorString.contains('405') ||
        errorString.contains('409') ||
        errorString.contains('422') ||
        errorString.contains('429') ||
        errorString.contains('bad request') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('not found') ||
        errorString.contains('conflict') ||
        errorString.contains('unprocessable') ||
        errorString.contains('rate limit');
  }

  /// Check if error is authentication-related
  static bool _isAuthError(String errorString) {
    return errorString.contains('authentication required') ||
        errorString.contains('session expired') ||
        errorString.contains('token refreshed, retry request') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401');
  }

  /// Check if error is timeout-related
  static bool _isTimeoutError(String errorString) {
    return (errorString.contains('timeout') &&
            !errorString.contains('connection timeout') &&
            !errorString.contains('gateway timeout')) ||
        errorString.contains('timeoutexception') ||
        errorString.contains('operation timed out');
  }

  /// Check if error is validation-related
  static bool _isValidationError(String errorString) {
    return errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('required') ||
        errorString.contains('422');
  }

  /// Handle authentication errors
  static void _handleAuthError(dynamic error) {
    if (error.toString().contains('Token refreshed, retry request')) {
      // Token was refreshed, this is not an error - just retry the request
      return;
    }

    // Clear tokens and redirect to login
    TokenService.clearTokens();

    // Show user-friendly message
    _showUserFriendlyError(
      'Your session has expired. Please log in again.',
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    );

    // Navigate to login after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      Get.offAllNamed('/login');
    });
  }

  /// Show user-friendly error message
  static void _showUserFriendlyError(
    String message, {
    Color? backgroundColor,
    Duration? duration,
    VoidCallback? onRetry,
  }) {
    if (_isShowingError) return;

    _isShowingError = true;

    Get.snackbar(
      'Oops!',
      message,
      backgroundColor: backgroundColor ?? Colors.red.shade600,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: Icon(
        Icons.info_outline,
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
      onTap: (_) => _isShowingError = false,
    ).future.then((_) => _isShowingError = false);
  }

  /// Handle specific API response errors with status codes
  static void handleApiResponseError(int statusCode, String? message) {
    final userFriendlyMessage = _getStatusCodeMessage(statusCode, message);

    switch (statusCode) {
      case 401:
        _handleAuthError('Authentication required');
        break;
      case 403:
        _showUserFriendlyError(userFriendlyMessage,
            backgroundColor: Colors.orange);
        break;
      case 404:
        _showUserFriendlyError(userFriendlyMessage,
            backgroundColor: Colors.orange);
        break;
      case 429:
        _showUserFriendlyError(userFriendlyMessage,
            backgroundColor: Colors.orange);
        break;
      case 500:
      case 501:
      case 502:
      case 503:
      case 504:
        _showUserFriendlyError(userFriendlyMessage);
        break;
      default:
        _showUserFriendlyError(userFriendlyMessage);
    }
  }

  /// Get user-friendly message for status codes
  static String _getStatusCodeMessage(int statusCode, String? originalMessage) {
    switch (statusCode) {
      case 400:
        return 'There was an issue with your request. Please check your input.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'The requested information could not be found.';
      case 409:
        return 'This action conflicts with existing data. Please refresh and try again.';
      case 422:
        return 'Please check your input and try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 501:
      case 502:
      case 503:
      case 504:
      case 505:
        return 'Our servers are temporarily unavailable. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Safe error logging (for debugging without exposing to users)
  static void logError(dynamic error, {String? context}) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] ERROR${context != null ? ' ($context)' : ''}: $error');

    // Here you could also send to crash reporting service like Firebase Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, null);
  }
}

/// Error types for categorization
enum ErrorType {
  authentication,
  network,
  server,
  client,
  validation,
  unknown,
}
