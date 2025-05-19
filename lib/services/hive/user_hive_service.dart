import 'package:hive/hive.dart';
import '../../models/hive/user_model.dart';

class UserHiveService {
  static const String _boxName = 'users';
  late Box<UserModel> _userBox;

  Future<void> init() async {
    _userBox = await Hive.openBox<UserModel>(_boxName);
  }

  Future<void> saveUser(UserModel user) async {
    await _userBox.put(user.id, user);
  }

  UserModel? getCurrentUser() {
    return _userBox.values.firstOrNull;
  }

  Future<void> clearUser() async {
    await _userBox.clear();
  }
}
