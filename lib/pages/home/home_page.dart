import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:whoosh/pages/client/viewclient_page.dart';
import 'package:whoosh/pages/login/login_page.dart';
import 'package:whoosh/pages/order/vieworder_page.dart';
import 'package:whoosh/services/api_service.dart';

import '../../components/menu_tile.dart';
import '../order/addorder_page.dart';
import '../journeyplan/journeyplans_page.dart';
import '../notice/noticeboard_page.dart';
import '../targets/targets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
    final user = box.read('user');

    setState(() {
      if (user != null && user is Map<String, dynamic>) {
        userName = user['name'] ?? 'User';
        userPhone = user['phoneNumber'] ?? 'No phone number';
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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
          child: CircularProgressIndicator(),
        ),
      );

      // Clear all stored data
      final box = GetStorage();
      await box.erase();

      // Close loading indicator
      if (!mounted) return;
      Navigator.pop(context);

      // Navigate to login page and clear all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;

      // Close loading indicator if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Moonsun Ltd'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),

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
                      title: 'Mechandiser',
                      subtitle: '$userName\n$userPhone',
                      icon: Icons.person,
                      onTap: () {
                        // TODO: Navigate to profile page
                      },
                    ),
                    MenuTile(
                      title: 'Journey Plans',
                      icon: Icons.map,
                      badgeCount: _isLoading ? null : _pendingJourneyPlans,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const JourneyPlansPage()),
                        ).then((_) => _loadPendingJourneyPlans());
                      },
                    ),
                    MenuTile(
                      title: 'View Client',
                      icon: Icons.storefront,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ViewClientPage()),
                        );
                      },
                    ),
                    MenuTile(
                      title: 'Notice Board',
                      icon: Icons.notifications,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const NoticeBoardPage()),
                        );
                      },
                    ),
                    MenuTile(
                      title: 'Add/Edit Order',
                      icon: Icons.edit,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ViewClientPage(
                                    forOrderCreation: true,
                                  )),
                        );
                      },
                    ),
                    MenuTile(
                      title: 'View Order',
                      icon: Icons.view_list,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ViewOrdersPage()),
                        );
                      },
                    ),
                    MenuTile(
                      title: 'View Targets',
                      icon: Icons.view_timeline_sharp,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TargetsPage()),
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
