import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';

class AuthController extends GetxController {
  final box = GetStorage();
  final isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  void checkAuthStatus() {
    final token = box.read('token');
    isLoggedIn.value = token != null;
  }

  Future<void> logout() async {
    await ApiService.logout();
    isLoggedIn.value = false;
    Get.offAllNamed('/login');
  }
}
