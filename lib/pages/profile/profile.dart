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
import 'package:woosh/services/session_state.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/models/hive/session_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final ProfileController controller = Get.put(ProfileController());
  final SessionState _sessionState = Get.put(SessionState());
  final SessionHiveService _sessionHiveService = SessionHiveService();
  bool isSessionActive = false;
  bool isProcessing = false;
  bool isCheckingSessionState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHive();
    _checkSessionStatus();
    // Add periodic session check
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkSessionTimeout();
    });
  }

  Future<void> _initHive() async {
    await _sessionHiveService.init();
  }

  Future<void> _checkSessionStatus() async {
    if (isCheckingSessionState) return;

    setState(() => isCheckingSessionState = true);
    final box = GetStorage();
    final userId = box.read<String>('userId');

    // First check Hive cache
    final cachedSession = await _sessionHiveService.getSession();
    if (cachedSession != null &&
        cachedSession.lastCheck != null &&
        DateTime.now().difference(cachedSession.lastCheck!) <
            const Duration(minutes: 1)) {
      setState(() {
        isSessionActive = cachedSession.isActive;
        isCheckingSessionState = false;
      });
      return;
    }

    if (userId != null) {
      try {
        final response = await SessionService.getSessionHistory(userId);
        final sessions = response['sessions'] as List;
        if (sessions.isNotEmpty) {
          final lastSession = sessions.first;
          final isActive = lastSession['logoutAt'] == null;
          final loginTime = DateTime.parse(lastSession['loginAt']);

          // Save to Hive
          await _sessionHiveService.saveSession(SessionModel(
            isActive: isActive,
            lastCheck: DateTime.now(),
            loginTime: loginTime,
            userId: userId,
          ));

          setState(() {
            isSessionActive = isActive;
          });
          _sessionState.updateSessionState(isActive, loginTime);
        }
      } catch (e) {
        print('Error checking session status: $e');
        // If API call fails, use cached value if available
        if (cachedSession != null) {
          setState(() {
            isSessionActive = cachedSession.isActive;
          });
        }
      }
    }
    setState(() => isCheckingSessionState = false);
  }

  Future<void> _checkSessionTimeout() async {
    final box = GetStorage();
    final userId = box.read<String>('userId');
    if (userId == null) return;

    // Check Hive cache first
    final cachedSession = await _sessionHiveService.getSession();
    if (cachedSession != null &&
        cachedSession.lastCheck != null &&
        DateTime.now().difference(cachedSession.lastCheck!) <
            const Duration(minutes: 1)) {
      if (!cachedSession.isActive && isSessionActive) {
        setState(() {
          isSessionActive = false;
        });
        Get.snackbar(
          'Session Expired',
          'Your session has expired. Please start a new session.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      return;
    }

    final isValid = await SessionService.isSessionValid(userId);
    if (!isValid && isSessionActive) {
      setState(() {
        isSessionActive = false;
      });

      // Update Hive cache
      await _sessionHiveService.saveSession(SessionModel(
        isActive: false,
        lastCheck: DateTime.now(),
        loginTime: cachedSession?.loginTime,
        userId: userId,
      ));

      Get.snackbar(
        'Session Expired',
        'Your session has expired. Please start a new session.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _toggleSession() async {
    if (isProcessing) return;

    // Show confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: GradientText(
          isSessionActive ? 'End Session' : 'Start Session',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isSessionActive
              ? 'Are you sure you want to end your current session?'
              : 'Are you sure you want to start a new session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          GoldGradientButton(
            onPressed: () => Get.back(result: true),
            child: Text(isSessionActive ? 'End Session' : 'Start Session'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() => isProcessing = true);
    final box = GetStorage();
    final userId = box.read<String>('userId');

    if (userId == null) {
      Get.snackbar(
        'Error',
        'User ID not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() => isProcessing = false);
      return;
    }

    try {
      if (!isSessionActive) {
        // Start session
        final response = await SessionService.recordLogin(userId);
        if (response['error'] != null) {
          // Show dialog for early login attempt
          if (response['error']
              .toString()
              .contains('Sessions can only be started from 9:00 AM')) {
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
          // Show snackbar for other errors
          Get.snackbar(
            'Cannot Start Session',
            response['error'],
            backgroundColor: Colors.white,
            colorText: Colors.orange,
            duration: const Duration(seconds: 5),
          );
          return;
        }

        // Save to Hive
        await _sessionHiveService.saveSession(SessionModel(
          isActive: true,
          lastCheck: DateTime.now(),
          loginTime: DateTime.now(),
          userId: userId,
        ));

        setState(() => isSessionActive = true);
        _sessionState.updateSessionState(true, DateTime.now());
        Get.snackbar(
          'Success',
          'Session started successfully',
          backgroundColor: Colors.white,
          colorText: Colors.green,
        );
      } else {
        // End session
        await SessionService.recordLogout(userId);

        // Update Hive
        await _sessionHiveService.saveSession(SessionModel(
          isActive: false,
          lastCheck: DateTime.now(),
          loginTime: null,
          userId: userId,
        ));

        setState(() => isSessionActive = false);
        _sessionState.updateSessionState(false, null);
        Get.snackbar(
          'Success',
          'Session ended successfully',
          backgroundColor: Colors.white,
          colorText: Colors.blue,
        );
      }
    } catch (e) {
      String errorMessage =
          'Failed to ${isSessionActive ? 'end' : 'start'} session';
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

  @override
  void dispose() {
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
                      Icons.history,
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
        // Session Control Button
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap:
                isProcessing || isCheckingSessionState ? null : _toggleSession,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSessionActive
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isSessionActive ? Icons.stop_circle : Icons.play_circle,
                      color: isSessionActive ? Colors.red : Colors.green,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isSessionActive ? 'End Session' : 'Start Session',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSessionActive ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  if (isCheckingSessionState)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16), // Add extra padding at the bottom
      ],
    );
  }
}
