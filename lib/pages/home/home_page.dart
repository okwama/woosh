import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/hive/session_model.dart';
import 'package:woosh/pages/Leave/leaveapplication_page.dart';
import 'package:woosh/pages/client/viewclient_page.dart';
import 'package:woosh/pages/journeyplan/reports/pages/product_return_page.dart';
import 'package:woosh/pages/login/login_page.dart';
import 'package:woosh/pages/order/viewOrder/vieworder_page.dart';
import 'package:woosh/pages/pos/upliftSaleCart_page.dart';
import 'package:woosh/pages/pos/uplift_sales_page.dart';
import 'package:woosh/pages/task/task.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/task_service.dart';
import 'package:woosh/pages/profile/profile.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/controllers/version_controller.dart';

import '../../components/menu_tile.dart';
import '../order/addorder_page.dart';
import '../journeyplan/journeyplans_page.dart';
import '../notice/noticeboard_page.dart';
import '../profile/targets/targets_page.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/services/session_state.dart';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/models/session_model.dart';
import 'package:woosh/controllers/auth_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String salesRepName;
  late String salesRepPhone;
  int _pendingJourneyPlans = 0;
  int _pendingTasks = 0;
  int _unreadNotices = 0;
  bool _isLoading = true;
  final TaskService _taskService = TaskService();
  final CartController _cartController = Get.put(CartController());

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPendingJourneyPlans();
    _loadPendingTasks();
    _loadUnreadNotices();

    // Check for app updates after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      final versionController = Get.find<VersionController>();
      versionController.showUpdateReminderIfNeeded();
    });
  }

  void _loadUserData() {
    final box = GetStorage();
    final salesRep = box.read('salesRep');

    setState(() {
      if (salesRep != null && salesRep is Map<String, dynamic>) {
        salesRepName = salesRep['name'] ?? 'User';
        salesRepPhone = salesRep['phoneNumber'] ?? 'No phone number';
      } else {
        salesRepName = 'User';
        salesRepPhone = 'No phone number';
      }
    });
  }

  Future<void> _loadPendingJourneyPlans() async {
    try {
      final journeyPlans = await ApiService.fetchJourneyPlans();

      // Get today's date in local time
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      setState(() {
        _pendingJourneyPlans = journeyPlans.where((plan) {
          // Convert plan date from UTC to local time
          final localDate = plan.date.toLocal();
          // Check if plan is pending AND is for today
          return plan.isPending &&
              localDate.year == today.year &&
              localDate.month == today.month &&
              localDate.day == today.day;
        }).length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending journey plans: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingTasks() async {
    try {
      final tasks = await _taskService.getTasks();
      setState(() {
        _pendingTasks = tasks.length;
      });
    } catch (e) {
      print('Error loading pending tasks: $e');
    }
  }

  Future<void> _loadUnreadNotices() async {
    try {
      final notices = await ApiService.getNotice();
      // Count notices from the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      setState(() {
        _unreadNotices = notices
            .where((notice) => notice.createdAt.isAfter(sevenDaysAgo))
            .length;
      });
    } catch (e) {
      print('Error loading unread notices: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      _loadPendingJourneyPlans(),
      _loadPendingTasks(),
      _loadUnreadNotices(),
    ]);
    _loadUserData();
  }

  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: GradientText('Logout',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            GoldGradientButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout != true) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: GradientCircularProgressIndicator(),
        ),
      );

      // Clear cart
      await _cartController.clear();

      // Clear all stored data
      final box = GetStorage();
      await box.erase();

      // Update auth controller state
      final authController = Get.find<AuthController>();
      await authController.logout();

      // Close loading indicator
      if (!mounted) return;
      Get.back();

      // Navigate to login page and clear all previous routes
      Get.offAllNamed('/login');
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;

      // Close loading indicator if it's showing
      if (Navigator.canPop(context)) {
        Get.back();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Woosh',
        actions: [
          Obx(() {
            final cartItems = _cartController.totalItems;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  tooltip: 'Cart',
                  onPressed: () {
                    Get.to(
                      () => const ViewOrdersPage(),
                      preventDuplicates: true,
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                if (cartItems > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$cartItems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _refreshData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing dashboard...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Menu section title
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            //   child: Row(
            //     children: [
            //       Icon(
            //         Icons.dashboard,
            //         size: 20,
            //         color: Theme.of(context).primaryColor,
            //       ),
            //       const SizedBox(width: 8),
            //       // Text(
            //       //   'Quick Actions',
            //       //   style: TextStyle(
            //       //     fontSize: 18,
            //       //     fontWeight: FontWeight.bold,
            //       //     color: Theme.of(context).primaryColor,
            //       //   ),
            //       // ),
            //     ],
            //   ),
            // ),

            // Grid menu items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 1.0,
                  mainAxisSpacing: 1.0,
                  children: [
                    // User Profile Tile (always active)
                    MenuTile(
                      title: 'Merchandiser',
                      subtitle: '$salesRepName\n$salesRepPhone',
                      icon: Icons.person,
                      onTap: () {
                        Get.to(
                          () => ProfilePage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    // Restricted tiles with opacity
                    MenuTile(
                      title: 'Journey Plans',
                      icon: Icons.map,
                      badgeCount: _isLoading ? null : _pendingJourneyPlans,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const JourneyPlansLoadingScreen(),
                        ),
                      ),
                    ),
                    MenuTile(
                      title: 'View Client',
                      icon: Icons.storefront_outlined,
                      onTap: () {
                        Get.to(
                          () => const ViewClientPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    // Notice Board (always active)
                    MenuTile(
                      title: 'Notice Board',
                      icon: Icons.notifications,
                      badgeCount: _unreadNotices,
                      onTap: () {
                        Get.to(
                          () => const NoticeBoardPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        )?.then((_) => _loadUnreadNotices());
                      },
                    ),
                    MenuTile(
                      title: 'Add/Edit Order',
                      icon: Icons.edit,
                      onTap: () {
                        Get.to(
                          () => const ViewClientPage(forOrderCreation: true),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    MenuTile(
                      title: 'View Orders',
                      icon: Icons.shopping_cart,
                      onTap: () {
                        Get.to(
                          () => const ViewOrdersPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    // Tasks (always active)
                    MenuTile(
                      title: 'Tasks',
                      icon: Icons.task,
                      badgeCount: _pendingTasks,
                      onTap: () {
                        Get.to(
                          () => const TaskPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        )?.then((_) => _loadPendingTasks());
                      },
                    ),
                    // Leave (always active)
                    MenuTile(
                      title: 'Leave',
                      icon: Icons.event_busy,
                      onTap: () {
                        Get.to(
                          () => const LeaveApplicationPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    MenuTile(
                      title: 'Uplift Sale',
                      icon: Icons.shopping_cart,
                      onTap: () {
                        Get.to(
                          () => const ViewClientPage(forUpliftSale: true),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        )?.then((selectedOutlet) {
                          if (selectedOutlet != null &&
                              selectedOutlet is Outlet) {
                            Get.off(
                              () => UpliftSaleCartPage(
                                outlet: selectedOutlet,
                              ),
                              transition: Transition.rightToLeft,
                            );
                          }
                        });
                      },
                    ),
                    MenuTile(
                      title: 'Product Return',
                      icon: Icons.assignment_return,
                      onTap: () {
                        Get.to(
                          () => const ViewClientPage(forProductReturn: true),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
