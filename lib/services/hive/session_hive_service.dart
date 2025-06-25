import 'package:hive/hive.dart';
import 'package:glamour_queen/models/hive/session_model.dart';

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

    // Check if session is active and last check was within 1 minute
    if (session.isActive && session.lastCheck != null) {
      final difference = DateTime.now().difference(session.lastCheck!);
      return difference < const Duration(minutes: 1);
    }
    return false;
  }
}

