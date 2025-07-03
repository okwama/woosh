import 'package:get/get.dart';
import '../services/hive/user_hive_service.dart' as hive;
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../models/hive/user_model.dart';
import '../services/token_service.dart';

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

  Future<void> handleLoginResult(Map<String, dynamic> loginResult) async {
    try {
      if (loginResult['success'] == true && loginResult['salesRep'] != null) {
        final user = UserModel.fromJson(loginResult['salesRep']);
        await _userHiveService.saveUser(user);

        _currentUser.value = user;
        _isLoggedIn.value = true;

        print('✅ AuthController: User logged in successfully');
        print('✅ AuthController: User ID: ${user.id}');
        print('✅ AuthController: User role: ${user.role}');
      } else {
        throw Exception(loginResult['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('AuthController handleLoginResult error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
<<<<<<< HEAD
      // Clear tokens using TokenService
      await TokenService.clearTokens();

      // Clear user data
=======
      await TokenService.clearTokens();
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      await _userHiveService.clearUser();
      _currentUser.value = null;
      _isLoggedIn.value = false;
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

<<<<<<< HEAD
  // Check if user is authenticated
=======
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  bool isAuthenticated() {
    return TokenService.isAuthenticated();
  }
}
