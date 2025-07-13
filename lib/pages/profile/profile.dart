import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/controllers/profile_controller.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:woosh/pages/profile/ChangePasswordPage.dart';
import 'package:woosh/pages/profile/deleteaccount.dart';
import 'package:woosh/pages/profile/targets/targets_page.dart';

import 'package:woosh/pages/profile/user_stats_page.dart';
import 'package:woosh/pages/profile/session_history_page.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/services/enhanced_session_service.dart';
import 'package:woosh/services/session_state.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/widgets/version_info_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/models/hive/session_model.dart';
import 'package:woosh/services/hive/cart_hive_service.dart';
import 'package:woosh/services/hive/client_hive_service.dart';
import 'package:woosh/services/hive/hive_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final ProfileController controller = Get.put(ProfileController());
  final SessionState _sessionState = Get.put(SessionState());
  bool isProcessing = false;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initEnhancedSessionService();
    // Force refresh session status on profile page load
    _sessionState.forceRefreshSessionStatus();
  }

  Future<void> _initEnhancedSessionService() async {
    await EnhancedSessionService.initialize();
  }

  Future<void> _toggleSession() async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      final box = GetStorage();
      final userId = box.read<String>('userId');

      if (userId == null) {
        Get.snackbar(
          'Error',
          'User ID not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (!_sessionState.isSessionActive.value) {
        // Start session using enhanced service with offline support
        final response = await EnhancedSessionService.recordLogin(userId);

        // Use the new startSession method to cache the session
        await _sessionState.startSession();
        _startDurationTimer();

        // Show appropriate success message
        final message = response['offline'] == true
            ? 'Session started (will sync when online)'
            : 'Session started successfully';
        final color =
            response['offline'] == true ? Colors.orange : Colors.green;

        Get.snackbar(
          'Success',
          message,
          backgroundColor: Colors.white,
          colorText: color,
        );
      } else {
        // Use the new endSession method to clear cache and end session
        await _sessionState.endSession();
        _stopDurationTimer();

        // Show success message
        Get.snackbar(
          'Success',
          'Session ended successfully',
          backgroundColor: Colors.white,
          colorText: Colors.blue,
        );
      }
    } catch (e) {
      // Handle server errors silently
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('Server error during session toggle - handled silently: $e');
        return;
      }

      String errorMessage =
          'Failed to ${_sessionState.isSessionActive.value ? 'end' : 'start'} session';
      Color errorColor = Colors.red;

      // Show dialog for early login attempt
      if (e.toString().contains('Sessions can only be started from 9:00 AM')) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Start Session'),
            content: const Text(
                'Sessions can only be started from 9:00 AM onwards. Please try again later.'),
            actions: [
              GoldGradientButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      Get.snackbar(
        'Error',
        errorMessage,
        backgroundColor: Colors.white,
        colorText: errorColor,
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _clearAppCache() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: GradientText(
          'Clear App Cache',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will clear all cached data including images, offline data, and temporary files. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          GoldGradientButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    try {
      // Clear image cache
      ImageCache().clear();
      ImageCache().clearLiveImages();

      // Clear API cache
      ApiCache.clear();

      // Clear Hive cache using correct methods
      final cartHiveService = CartHiveService();
      await cartHiveService.init();
      await cartHiveService.clearCart();

      final clientHiveService = ClientHiveService();
      await clientHiveService.init();
      await clientHiveService.clearAllClients();

      Get.snackbar(
        'Success',
        'App cache cleared successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to clear cache: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getSessionDuration() {
    if (_sessionState.sessionStartTime.value == null) return 'N/A';

    final now = DateTime.now();
    final startTime = _sessionState.sessionStartTime.value!;
    final duration = now.difference(startTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _startDurationTimer() {
    _stopDurationTimer(); // Stop any existing timer
    _durationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _sessionState.isSessionActive.value) {
        setState(() {}); // Trigger rebuild to update duration
      } else {
        timer.cancel();
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    _stopDurationTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    ImageCache().clear();
    ImageCache().clearLiveImages();
    ApiCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Profile',
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.fetchProfile();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          Obx(
            () => AnimationLimiter(
              child: SingleChildScrollView(
                child: Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      const SizedBox(height: 16),
                      // Profile Image Section
                      _buildProfileImageSection(),
                      // Role Badge
                      const SizedBox(height: 8),
                      _buildRoleBadge(),
                      const SizedBox(height: 16),
                      // Profile Info Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            _buildInfoCard(
                              context,
                              icon: Icons.person,
                              label: 'Name',
                              value: controller.userName.value,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoCard(
                              context,
                              icon: Icons.email,
                              label: 'Email',
                              value: controller.userEmail.value,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoCard(
                              context,
                              icon: Icons.phone,
                              label: 'Phone',
                              value: controller.userPhone.value,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButtons(),
                            const SizedBox(height: 16),
                            // Version Info Widget
                            const VersionInfoWidget(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: controller.photoUrl.value.isNotEmpty
                ? Image.network(
                    controller.photoUrl.value,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, size: 50, color: Colors.grey),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.grey),
                  ),
          ),
        ),
        if (controller.isLoading.value)
          const Positioned.fill(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              onPressed: controller.pickImage,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge() {
    final String role = controller.userRole.value.isEmpty
        ? '`User`'
        : controller.userRole.value;

    final Color badgeColor =
        role.toLowerCase() == 'supervisor' || role.toLowerCase() == 'admin'
            ? Colors.red.shade700
            : role.toLowerCase() == 'manager'
                ? Colors.blue.shade700
                : Colors.green.shade700;

    final IconData roleIcon =
        role.toLowerCase() == 'supervisor' || role.toLowerCase() == 'admin'
            ? Icons.supervised_user_circle
            : role.toLowerCase() == 'manager'
                ? Icons.manage_accounts
                : Icons.security;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleIcon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? 'Not provided' : value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              Get.to(() => const UserStatsPage());
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.analytics,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'View My Statistics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              Get.to(() => const SessionHistoryPage());
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'View Session History',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              Get.to(() => const ChangePasswordPage());
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              Get.to(() => const TargetsPage());
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.track_changes,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'View Targets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              Get.to(() => const DeleteAccount());
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: _clearAppCache,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.cleaning_services,
                      color: Colors.orange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Clear App Cache',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade600,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Simplified Session Control Button
        Obx(() => Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _sessionState.isSessionActive.value
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_sessionState.isSessionActive.value
                            ? Colors.red
                            : Colors.green)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isProcessing || _sessionState.isCheckingSession.value
                      ? null
                      : _toggleSession,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _sessionState.isSessionActive.value
                                ? Icons.stop_circle
                                : Icons.play_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sessionState.isSessionActive.value
                                    ? 'End Session'
                                    : 'Start Session',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_sessionState.isSessionActive.value &&
                                  _sessionState.sessionStartTime.value !=
                                      null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Duration: ${_getSessionDuration()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
        const SizedBox(height: 16), // Add extra padding at the bottom
      ],
    );
  }
}
