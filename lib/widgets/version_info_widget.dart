import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/controllers/version_controller.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_widgets.dart';

class VersionInfoWidget extends StatelessWidget {
  const VersionInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final versionController = Get.find<VersionController>();

    return Obx(() {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: goldMiddle2),
                  const SizedBox(width: 8),
                  const Text(
                    'App Version',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (versionController.isCheckingUpdate.value)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Current Version: '),
                  Text(
                    versionController.currentVersion.value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status: '),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: versionController.hasUpdate.value
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      versionController.updateStatus,
                      style: TextStyle(
                        color: versionController.hasUpdate.value
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: versionController.isCheckingUpdate.value
                          ? null
                          : () => versionController.forceCheckForUpdates(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check for Updates'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (versionController.hasUpdate.value)
                    Expanded(
                      child: GoldGradientButton(
                        onPressed: () =>
                            versionController.forceCheckForUpdates(),
                        child: const Text('Update Now'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
