import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:woosh/pages/404/noConnection_page.dart';
import 'package:woosh/pages/home/home_page.dart';
import 'package:woosh/pages/login/login_page.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/auth_controller.dart';

// Custom color scheme
const Color primaryBlack = Color(0xFFDAA520);
const Color secondaryGrey = Color.fromARGB(255, 0, 0, 0);
const Color accentGrey = Color(0xFF666666);
const Color lightGrey = Color.fromARGB(255, 236, 235, 227);
const Color backgroundColor = Color(0xFFFDFBD4);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // Initialize GetStorage
  Get.put(AuthController()); // Initialize AuthController
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
      theme: ThemeData(
        primaryColor: primaryBlack,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.light(
          primary: primaryBlack,
          secondary: secondaryGrey,
          surface: Color(0xFFFDFBD4),
          background: backgroundColor,
          error: Colors.red,
          onPrimary: Color(0xFFFDFBD4),
          onSecondary: Color(0xFFFDFBD4),
          onSurface: primaryBlack,
          onBackground: primaryBlack,
          onError: Color(0xFFFDFBD4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlack,
          foregroundColor: Color(0xFFFDFBD4),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFFDFBD4),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlack,
            foregroundColor: const Color(0xFFFDFBD4),
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
          fillColor: const Color(0xFFFDFBD4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: lightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: lightGrey),
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