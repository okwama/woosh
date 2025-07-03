import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:woosh/pages/404/offlineToast.dart';
import 'package:woosh/pages/home/home_page.dart';
import 'package:woosh/pages/login/login_page.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/routes/app_routes.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/controllers/uplift_cart_controller.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/utils/hive/hive_initializer.dart';
import 'package:hive/hive.dart';
import 'package:woosh/models/hive/session_model.dart';
import 'package:woosh/services/hive/session_hive_service.dart';
import 'package:woosh/services/permission_service.dart';
import 'package:woosh/services/outlet_service.dart';
import 'package:woosh/pages/activation_page.dart';
import 'package:woosh/pages/test/error_test_page.dart';
import 'package:woosh/services/offline_sync_service.dart';
import 'package:woosh/services/enhanced_session_service.dart';
import 'package:woosh/services/enhanced_journey_plan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await GetStorage.init();
    // Initialize Hive with all adapters
    await HiveInitializer.initialize();

    // Initialize enhanced services
    await EnhancedSessionService.initialize();
    await EnhancedJourneyPlanService.initialize();

    // Initialize offline sync service
    Get.put(OfflineSyncService());

    // Request permissions at startup
    await PermissionService.requestInitialPermissions();

    // Initialize services
    Get.put(OutletService());

    Get.put(AuthController());
    Get.put(UpliftCartController());
    runApp(MyApp());
  } catch (e) {
    print('❌ Error initializing services: $e');
    // Continue with app launch even if some services fail
  }
}

class MyApp extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Whoosh',
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 200),
      theme: ThemeData(
        primaryColor:
            goldMiddle2, // Use goldMiddle2 as primary color (most similar to previous gold)
        scaffoldBackgroundColor: appBackground,
        colorScheme: ColorScheme.light(
          primary: goldMiddle2,
          secondary: blackColor,
          surface: const Color(
              0xFFF4EBD0), // Update surface color to match background
          background: appBackground,
          error: Colors.red,
          onPrimary: const Color(0xFFFDFBD4),
          onSecondary: const Color.fromARGB(255, 252, 252, 252),
          onSurface: goldMiddle2,
          onBackground: const Color.fromARGB(255, 252, 252, 252),
          onError: const Color.fromARGB(255, 255, 255, 255),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: goldMiddle2,
          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color.fromARGB(255, 255, 255, 255),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: goldMiddle2,
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: goldMiddle2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(255, 255, 255, 255),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color.fromARGB(255, 156, 156, 153)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color.fromARGB(255, 188, 188, 188)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: goldMiddle2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.quicksandTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: Obx(() {
        if (!authController.isInitialized.value) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // Check if user is authenticated using TokenService
        final isAuthenticated = TokenService.isAuthenticated();

        if (!isAuthenticated || !authController.isLoggedIn.value) {
          return const LoginPage();
        } else {
          // All authenticated users go to HomePage
          return HomePage();
        }
      }),
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/no_connection', page: () => const OfflineToast()),
        ...AppRoutes.routes,
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      final authController = Get.put(AuthController());
      final isLoggedIn = await authController.isLoggedIn();

      if (isLoggedIn) {
        Get.offAll(() => const HomePage());
      } else {
        Get.offAll(() => const LoginPage());
      }
    } catch (e) {
      print('Error checking auth status: $e');
      Get.offAll(() => const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/woosh_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.business,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // App name
            Text(
              'Woosh',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sales Management System',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
