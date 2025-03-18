import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:whoosh/pages/404/noConnection_page.dart';
import 'package:whoosh/pages/home_page.dart';
import 'package:whoosh/pages/login_page.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // Initialize GetStorage
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GetStorage box = GetStorage();

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Whoosh',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _getInitialScreen(),
      getPages: [
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/home', page: () => HomePage()),
        // GetPage(name: '/no_connection', page: () => NoConnectionPage()),
      ],
    );
  }

  Widget _getInitialScreen() {
    // Check if the user is logged in
    String? token = box.read('token'); // Read stored token
    return token != null ? HomePage() : LoginPage(); // Navigate based on token existence
  }
}
