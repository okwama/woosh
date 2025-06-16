import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OfflineToastService {
  static void showOfflineToast({
    String message = "You're offline",
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
  }) {
    Get.rawSnackbar(
      messageText: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Get.theme.colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Get.theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Get.back();
                  onRetry();
                },
                child: Icon(
                  Icons.refresh_rounded,
                  color: Get.theme.colorScheme.onErrorContainer,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      snackPosition: SnackPosition.TOP,
      animationDuration: const Duration(milliseconds: 300),
    );
  }
}
