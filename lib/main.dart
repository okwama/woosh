import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:woosh/pages/404/noConnection_page.dart';
import 'package:woosh/pages/home/home_page.dart';
import 'package:woosh/pages/login/login_page.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';


// Custom color scheme
const Color primaryBlack = Color(
    0xFFF1AD1A); // Changed to primary gradient color for theme compatibility
const Color secondaryGrey = Color.fromARGB(255, 0, 0, 0);
const Color accentGrey = Color(0xFF666666);
const Color lightGrey = Color.fromARGB(255, 255, 255, 255);
const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);

// Custom gradients
const LinearGradient primaryGradient = LinearGradient(
  colors: [
    Color(0xFFF1AD1A),
    Color(0xFFFFD46E),
    Color(0xFFDE9F2D),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // Request location permission
    await Permission.location.request();

    // Request camera permission if needed
    await Permission.camera.request();

    // Request notification permission for Android 13+
    if (androidInfo.version.sdkInt >= 33) {
      await Permission.notification.request();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // Initialize GetStorage
  await requestPermissions(); // Request permissions before app starts
  Get.put(AuthController()); // Initialize AuthController
  Get.put(CartController()); // Initialize CartController
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Whoosh',
      defaultTransition: Transition.cupertino, // Smoother transitions
      transitionDuration: const Duration(milliseconds: 200),
      popGesture: true, // Enable swipe to go back
      defaultGlobalState: true, // Enable global state management
      navigatorKey: Get.key, // Use GetX's navigator key
      theme: ThemeData(
        primaryColor: primaryBlack,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.light(
          primary: primaryBlack,
          secondary: secondaryGrey,
          surface: Color(0xFFFDFBD4),
          background: backgroundColor,
          error: Colors.red,
          onPrimary: Color.fromARGB(255, 255, 255, 255),
          onSecondary: Color.fromARGB(255, 255, 255, 255),
          onSurface: primaryBlack,
          onBackground: primaryBlack,
          onError: Color.fromARGB(255, 255, 255, 255),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlack,
          foregroundColor: Color.fromARGB(255, 255, 255, 255),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color.fromARGB(255, 255, 255, 255),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlack,
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlack,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(255, 255, 255, 255),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: lightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color.fromARGB(255, 194, 193, 193)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryBlack),
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
      home:
          Obx(() => authController.isLoggedIn.value ? HomePage() : LoginPage()),
      getPages: [
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/no_connection', page: () => const NoConnectionPage()),
      ],
    );
  }
}
