import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/controllers/auth_controller.dart';

class GlobalErrorHandler {
  static void handleApiError(dynamic error) {
    print('Global error handler: $error');

    if (error.toString().contains('Authentication required') ||
        error.toString().contains('Session expired') ||
        error.toString().contains('Token refreshed, retry request')) {
      // Handle authentication errors
      _handleAuthError(error);
    } else {
      // Handle other errors
      _handleGeneralError(error);
    }
  }

  static void _handleAuthError(dynamic error) {
    if (error.toString().contains('Token refreshed, retry request')) {
      // Token was refreshed, this is not an error - just retry the request
      return;
    }

    // Clear tokens and redirect to login
    TokenService.clearTokens();

    // Show user-friendly message
    Get.snackbar(
      'Session Expired',
      'Please log in again to continue.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Navigate to login
    Get.offAllNamed('/login');
  }

  static void _handleGeneralError(dynamic error) {
    String errorMessage = 'Something went wrong. Please try again.';

    if (error.toString().contains('Network error') ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection timeout')) {
      errorMessage = 'Network error. Please check your connection.';
    } else if (error.toString().contains('TimeoutException')) {
      errorMessage = 'Request timed out. Please try again.';
    } else if (error.toString().contains('500')) {
      errorMessage = 'Server error. Please try again later.';
    }

    Get.snackbar(
      'Error',
      errorMessage,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  // Handle specific API response errors
  static void handleApiResponseError(int statusCode, String? message) {
    switch (statusCode) {
      case 401:
        _handleAuthError('Authentication required');
        break;
      case 403:
        Get.snackbar(
          'Access Denied',
          'You do not have permission to perform this action.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        break;
      case 404:
        Get.snackbar(
          'Not Found',
          'The requested resource was not found.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        break;
      case 500:
        Get.snackbar(
          'Server Error',
          'Server error occurred. Please try again later.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        break;
      default:
        Get.snackbar(
          'Error',
          message ?? 'An unexpected error occurred.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
    }
  }
}
