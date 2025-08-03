import 'package:flutter/material.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/utils/app_theme.dart';

class AssetRequestsPage extends StatefulWidget {
  const AssetRequestsPage({super.key});

  @override
  State<AssetRequestsPage> createState() => _AssetRequestsPageState();
}

class _AssetRequestsPageState extends State<AssetRequestsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Asset Requests',
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.request_page,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Asset Requests feature is under development.\n\nYou will soon be able to request merchandising display items, product samples, and other assets needed for your work.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
