import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/pages/Leave/leaveapplication_page.dart';
import 'package:glamour_queen/pages/client/viewclient_page.dart';
import 'package:glamour_queen/pages/login/login_page.dart';
import 'package:glamour_queen/pages/managers/history_page.dart';
import 'package:glamour_queen/pages/order/viewOrder/vieworder_page.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/pages/profile/profile.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'package:glamour_queen/widgets/gradient_widgets.dart';

import '../../components/menu_tile.dart';
import '../order/addorder_page.dart';
import '../journeyplan/journeyplans_page.dart';
import '../notice/noticeboard_page.dart';
import '../profile/targets/targets_page.dart';
import 'checkin_page.dart';
import 'package:glamour_queen/pages/managers/teamRepor/salesrep_reports_page.dart';

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  _ManagerHomePageState createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  late String userName;
  late String userPhone;
  
  int _pendingJourneyPlans = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPendingJourneyPlans();
  }

  void _loadUserData() {
    final box = GetStorage();
    final salesRep = box.read('salesRep');

    setState(() {
      if (salesRep != null && salesRep is Map<String, dynamic>) {
        userName = salesRep['name'] ?? 'User';
        userPhone = salesRep['phoneNumber'] ?? 'No phone number';
      } else {
        userName = 'User';
        userPhone = 'No phone number';
      }
    });
  }

  Future<void> _loadPendingJourneyPlans() async {
    try {
      final journeyPlans = await ApiService.fetchJourneyPlans();
      setState(() {
        _pendingJourneyPlans =
            journeyPlans.where((plan) => plan.isPending).length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending journey plans: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadPendingJourneyPlans();
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

      // Clear all stored data
      final box = GetStorage();
      await box.erase();

      // Close loading indicator
      if (!mounted) return;
      Get.back();

      // Navigate to login page and clear all previous routes
      Get.offAll(() => const LoginPage());
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
                    // User Profile Tile
                    MenuTile(
                      title: 'Manager',
                      subtitle: '$userName\n$userPhone',
                      icon: Icons.person,
                      onTap: () {
                        Get.to(
                          () => ProfilePage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    MenuTile(
                      title: 'Check In',
                      icon: Icons.map,
                      badgeCount: _isLoading ? null : _pendingJourneyPlans,
                      onTap: () {
                        Get.to(
                          () => const CheckInPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        )?.then((_) => _loadPendingJourneyPlans());
                      },
                    ),
                    MenuTile(
                      title: 'History',
                      icon: Icons.history_edu_outlined,
                      onTap: () {
                        Get.to(
                          () => const CheckInHistoryPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    MenuTile(
                      title: 'Team Reports',
                      icon: Icons.assignment_ind,
                      onTap: () {
                        Get.to(
                          () => const SalesRepReportsPage(),
                          preventDuplicates: true,
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    // MenuTile(
                    //   title: 'Notice Board',
                    //   icon: Icons.notifications,
                    //   onTap: () {
                    //     Get.to(
                    //       () => const NoticeBoardPage(),
                    //       preventDuplicates: true,
                    //       transition: Transition.rightToLeft,
                    //     );
                    //   },
                    // ),
                    // MenuTile(
                    //   title: 'Add/Edit Order',
                    //   icon: Icons.edit,
                    //   onTap: () {
                    //     Get.to(
                    //       () => const ViewClientPage(forOrderCreation: true),
                    //       preventDuplicates: true,
                    //       transition: Transition.rightToLeft,
                    //     );
                    //   },
                    // ),
                    // MenuTile(
                    //   title: 'View Orders',
                    //   icon: Icons.shopping_cart,
                    //   onTap: () {
                    //     Get.to(
                    //       () => const ViewOrdersPage(),
                    //       preventDuplicates: true,
                    //       transition: Transition.rightToLeft,
                    //     );
                    //   },
                    // ),
                    // MenuTile(
                    //   title: 'Targets',
                    //   icon: Icons.track_changes,
                    //   onTap: () {
                    //     Get.to(
                    //       () => const TargetsPage(),
                    //       preventDuplicates: true,
                    //       transition: Transition.rightToLeft,
                    //     );
                    //   },
                    // ),
                    // MenuTile(
                    //   title: 'Leave',
                    //   icon: Icons.event_busy,
                    //   onTap: () {
                    //     Get.to(
                    //       () => const LeaveApplicationPage(),
                    //       preventDuplicates: true,
                    //       transition: Transition.rightToLeft,
                    //     );
                    //   },
                    // ),
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

