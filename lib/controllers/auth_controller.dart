import 'package:get/get.dart';
import '../services/hive/user_hive_service.dart' as hive;
import '../services/api_service.dart';
import '../models/hive/user_model.dart';

class AuthController extends GetxController {
  final hive.UserHiveService _userHiveService = hive.UserHiveService();
  final _isLoggedIn = false.obs;
  final _currentUser = Rxn<UserModel>();

  RxBool get isLoggedIn => _isLoggedIn;
  UserModel? get currentUser => _currentUser.value;

  @override
  void onInit() {
    super.onInit();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    await _userHiveService.init();
    await _loadUserFromHive();
  }

  Future<void> _loadUserFromHive() async {
    final user = _userHiveService.getCurrentUser();
    if (user != null) {
      _currentUser.value = user;
      _isLoggedIn.value = true;
    }
  }

  Future<void> login(String phoneNumber, String password) async {
    try {
      final response = await ApiService().login(phoneNumber, password);
      if (response['success'] == true && response['salesRep'] != null) {
        final user = UserModel.fromJson(response['salesRep']);
        await _userHiveService.saveUser(user);

        _currentUser.value = user;
        _isLoggedIn.value = true;
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _userHiveService.clearUser();
      _currentUser.value = null;
      _isLoggedIn.value = false;
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }
}
