import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/progressive_login_service.dart';

class ProgressiveLoginStatus extends StatelessWidget {
  const ProgressiveLoginStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      try {
        final progressiveService = Get.find<ProgressiveLoginService>();

        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    progressiveService.isOnline ? Icons.wifi : Icons.wifi_off,
                    color:
                        progressiveService.isOnline ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Progressive Login Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Network: ${progressiveService.isOnline ? "Online" : "Offline"}',
                style: TextStyle(fontSize: 10),
              ),
              Text(
                'Sync: ${progressiveService.isSyncing ? "Syncing..." : "Idle"}',
                style: TextStyle(fontSize: 10),
              ),
              Text(
                'Pending: ${progressiveService.pendingLogins.length}',
                style: TextStyle(fontSize: 10),
              ),
              Text(
                'Status: ${progressiveService.getSyncStatus()}',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      } catch (e) {
        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Text(
            'Progressive Login Service not available',
            style: TextStyle(
              fontSize: 10,
              color: Colors.red.shade700,
            ),
          ),
        );
      }
    });
  }
}
