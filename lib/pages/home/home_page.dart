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
import 'package:woosh/pages/task/task.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/hive/client_hive_service.dart';
import 'package:woosh/services/hive/order_hive_service.dart';
import 'package:woosh/services/hive/product_hive_service.dart';
import 'package:woosh/services/hive/route_hive_service.dart';
import 'package:woosh/services/jouneyplan_service.dart';
import 'package:woosh/services/task_service.dart';
import 'package:woosh/pages/profile/profile.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/widgets/offline_sync_indicator.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';

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
import 'package:woosh/services/version_check_service.dart';
import 'dart:async';

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
  final SessionState _sessionState = Get.put(SessionState());

  @override
  void initState() {
    super.initState();
    // Load user data immediately (fast, local)
    _loadUserData();

    // Initialize session service (fast, local)
    _initSessionService();

    // Load data asynchronously to avoid blocking UI
    _loadDataAsync();
  }

  void _loadDataAsync() {
    // Load data in parallel to reduce total time
    Future.wait([
      _loadPendingJourneyPlans(),
      _loadPendingTasks(),
      _loadUnreadNotices(),
    ]).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      final journeyPlans = await JourneyPlanService.fetchJourneyPlans();

      // Get today's date in local time
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      setState(() {
        _pendingJourneyPlans = journeyPlans.data.where((plan) {
          // Convert plan date from UTC to local time
          final localDate = plan.date.toLocal();
          // Check if plan is pending AND is for today
          return plan.isPending &&
              localDate.year == today.year &&
              localDate.month == today.month &&
              localDate.day == today.day;
        }).length;
      });
    } catch (e) {
      print('Error loading pending journey plans: $e');
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
      // Count notices from the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      setState(() {
        _unreadNotices = notices
            .where((notice) => notice.createdAt.isAfter(thirtyDaysAgo))
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

    try {
      // Clear all app caches
      print('?? Clearing app cache...');
      ApiService.clearCache();

      // Clear specific caches that might be stale
      ApiService.clearOutletsCache();
      ApiService.clearProductCache();

      // Clear Hive caches if services are available
      try {
        // Clear client cache
        final clientHiveService = Get.find<ClientHiveService>();
        await clientHiveService.clearAllClients();
        print('?? Cleared client Hive cache');
      } catch (e) {
        print('?? Could not clear client Hive cache: $e');
      }

      try {
        // Clear product cache
        final productHiveService = Get.find<ProductHiveService>();
        await productHiveService.clearAllProducts();
        print('?? Cleared product Hive cache');
      } catch (e) {
        print('?? Could not clear product Hive cache: $e');
      }

      try {
        // Clear order cache
        final orderHiveService = Get.find<OrderHiveService>();
        await orderHiveService.clearAllOrders();
        print('?? Cleared order Hive cache');
      } catch (e) {
        print('?? Could not clear order Hive cache: $e');
      }

      try {
        // Clear route cache
        final routeHiveService = Get.find<RouteHiveService>();
        await routeHiveService.clearAllRoutes();
        print('?? Cleared route Hive cache');
      } catch (e) {
        print('?? Could not clear route Hive cache: $e');
      }

      // Clear any other cached data
      final box = GetStorage();
      final keys = box.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_') ||
            key.startsWith('outlets_') ||
            key.startsWith('products_') ||
            key.startsWith('routes_') ||
            key.startsWith('notices_') ||
            key.startsWith('clients_') ||
            key.startsWith('orders_')) {
          box.remove(key);
          print('?? Cleared cache key: $key');
        }
      }

      print('?? Cache cleared successfully');

      // Reload all data
      await Future.wait([
        _loadPendingJourneyPlans(),
        _loadPendingTasks(),
        _loadUnreadNotices(),
        _sessionState.checkSessionStatus(),
      ]);
      _loadUserData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('? Dashboard refreshed and all caches cleared'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('? Error during refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?? Refresh completed with some errors: $e'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

      // Show immediate loading feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Logging out...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Clear user data immediately for fast logout
      final box = GetStorage();
      await box.remove('salesRep');
      await box.remove('token');
      await box.remove('userId');

      // Navigate immediately
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );

      // Clear caches in background (non-blocking)
      _clearCachesInBackground();
    } catch (e) {
      // Even if there's an error, still logout
      final box = GetStorage();
      await box.remove('salesRep');
      await box.remove('token');
      await box.remove('userId');

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  // Background cache clearing (non-blocking)
  Future<void> _clearCachesInBackground() async {
    try {
      final box = GetStorage();

      // Clear all cached data
      await box.remove('cached_products');
      await box.remove('products_last_update');
      await box.remove('cached_clients');
      await box.remove('cached_routes');
      await box.remove('cached_outlets');

      // Clear Hive caches
      try {
        final hiveService = Get.find<dynamic>();
        if (hiveService != null) {
          await hiveService.clearAll();
        }
      } catch (e) {
        // Ignore Hive errors
      }

      // Clear API caches
      try {
        ApiService
            .clearCache(); // Changed from ApiCache.clear() to ApiService.clearCache()
      } catch (e) {
        // Ignore cache errors
      }
    } catch (e) {
      // Silent fail - user is already logged out
    }
  }

  Future<void> _initSessionService() async {
    // SessionState handles initialization automatically
  }

  void _handleJourneyPlansNavigation() {
    // Use centralized SessionState for session status
    if (_sessionState.isCheckingSession.value) {
      // Show loading dialog while checking session status
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking session status...'),
            ],
          ),
        ),
      );
      return;
    }

    if (!_sessionState.isSessionActive.value) {
      // Show dialog to start session
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange),
              SizedBox(width: 8),
              const Text('Session Required'),
            ],
          ),
          content: const Text(
            'You need to start your work session to access Journey Plans. Would you like to start your session now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to profile page to start session
                Get.to(
                  () => const ProfilePage(),
                  preventDuplicates: true,
                  transition: Transition.rightToLeft,
                )?.then((_) {
                  // Check session status when returning from profile page
                  _sessionState.checkSessionStatus().then((isActive) {
                    // If session is now active, automatically navigate to journey plans
                    if (isActive) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const JourneyPlansLoadingScreen(),
                        ),
                      );
                    }
                  });
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Session'),
            ),
          ],
        ),
      );
    } else {
      // Session is active, proceed to journey plans
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JourneyPlansLoadingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building HomePage - _unreadNotices: $_unreadNotices, _isLoading: $_isLoading');
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'WOOSH',
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
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh & Clear Cache',
            onPressed: _isLoading
                ? null
                : () {
                    // Show immediate feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '?? Refreshing dashboard and clearing cache...'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.blue,
                      ),
                    );

                    // Start the refresh process
                    _refreshData();
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
            // Offline sync indicator
            const OfflineSyncIndicator(),
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
                    Obx(() => MenuTile(
                          title: 'Merchandiser',
                          subtitle: _sessionState.isCheckingSession.value
                              ? '$salesRepName\n$salesRepPhone\nChecking session...'
                              : _sessionState.isSessionActive.value
                                  ? '$salesRepName\n$salesRepPhone\n🟢 Session Active'
                                  : '$salesRepName\n$salesRepPhone\n🔴 Session Inactive',
                          icon: Icons.person,
                          onTap: () {
                            Get.to(
                              () => ProfilePage(),
                              preventDuplicates: true,
                              transition: Transition.rightToLeft,
                            )?.then((_) => _sessionState
                                .checkSessionStatus()); // Refresh session status when returning
                          },
                        )),
                    // Restricted tiles with opacity
                    Obx(() => MenuTile(
                          title: 'Journey Plans',
                          icon: Icons.map,
                          badgeCount: _isLoading ? null : _pendingJourneyPlans,
                          onTap: () => _handleJourneyPlansNavigation(),
                          subtitle: !_sessionState.isSessionActive.value
                              ? '🔒 Session Required'
                              : null,
                          opacity:
                              _sessionState.isSessionActive.value ? 1.0 : 0.6,
                        )),
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
                      badgeCount: _unreadNotices > 0 ? _unreadNotices : null,
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
                      title: 'Tasks/Warnings',
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
                      title: 'Uplift Sales History',
                      icon: Icons.history,
                      onTap: () {
                        Get.toNamed('/uplift-sales');
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
