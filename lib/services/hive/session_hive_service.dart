import 'package:hive/hive.dart';
import 'package:woosh/models/hive/session_model.dart';

class SessionHiveService {
  static const String _boxName = 'sessionBox';
  static const String _sessionKey = 'currentSession';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<SessionModel>(_boxName);
    }
  }

  Future<void> saveSession(SessionModel session) async {
    final box = await Hive.openBox<SessionModel>(_boxName);
    await box.put(_sessionKey, session);
  }

  Future<SessionModel?> getSession() async {
    final box = await Hive.openBox<SessionModel>(_boxName);
    return box.get(_sessionKey);
  }

  Future<void> clearSession() async {
    final box = await Hive.openBox<SessionModel>(_boxName);
    await box.delete(_sessionKey);
  }

  Future<bool> isSessionValid() async {
    final session = await getSession();
    if (session == null) return false;

    // Session is valid if it exists - no time-based expiration
    return true;
  }
}
