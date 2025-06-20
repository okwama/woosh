import 'package:get/get.dart';
import '../services/hive/user_hive_service.dart' as hive;
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../models/hive/user_model.dart';

class AuthController extends GetxController {
  final hive.UserHiveService _userHiveService = hive.UserHiveService();
  final _isLoggedIn = false.obs;
  final _currentUser = Rxn<UserModel>();
  final _isInitialized = false.obs;

  RxBool get isLoggedIn => _isLoggedIn;
  UserModel? get currentUser => _currentUser.value;
  RxBool get isInitialized => _isInitialized;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    await _userHiveService.init();
    await _loadUserFromHive();
    _isInitialized.value = true;
  }

  Future<void> _loadUserFromHive() async {
    final user = _userHiveService.getCurrentUser();
    if (user != null && TokenService.isAuthenticated()) {
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
      // Clear tokens using TokenService
      await TokenService.clearTokens();

      // Clear user data
      await _userHiveService.clearUser();
      _currentUser.value = null;
      _isLoggedIn.value = false;
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    return TokenService.isAuthenticated();
  }
}
