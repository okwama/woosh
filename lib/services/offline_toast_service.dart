import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OfflineToastService {
  static bool _isShowing = false;

  static void show({
    String message = "No internet connection",
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    Get.rawSnackbar(
      messageText: _buildToastContent(message, onRetry),
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      snackPosition: SnackPosition.BOTTOM,
      animationDuration: const Duration(milliseconds: 250),
      reverseAnimationCurve: Curves.easeOut,
      forwardAnimationCurve: Curves.easeOut,
      onTap: (_) => _dismiss(),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    ).future.then((_) => _isShowing = false);
  }

  static Widget _buildToastContent(String message, VoidCallback? onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Get.theme.colorScheme.errorContainer,
            Get.theme.colorScheme.errorContainer.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Get.theme.colorScheme.outline.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Get.theme.colorScheme.onErrorContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              color: Get.theme.colorScheme.onErrorContainer,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Get.textTheme.bodyMedium?.copyWith(
                color: Get.theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            _buildRetryButton(onRetry),
          ],
        ],
      ),
    );
  }

  static Widget _buildRetryButton(VoidCallback onRetry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _dismiss();
          onRetry();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.onErrorContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.refresh_rounded,
            color: Get.theme.colorScheme.onErrorContainer,
            size: 16,
          ),
        ),
      ),
    );
  }

  static void _dismiss() {
    Get.closeCurrentSnackbar();
    _isShowing = false;
  }
}