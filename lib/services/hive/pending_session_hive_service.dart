import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../models/hive/pending_session_model.dart';

class PendingSessionHiveService {
  static const String _boxName = 'pendingSessions';
  late Box<PendingSessionModel> _pendingSessionBox;
  final _uuid = const Uuid();

  Future<void> init() async {
    _pendingSessionBox = await Hive.openBox<PendingSessionModel>(_boxName);
  }

  Future<String> savePendingSession(PendingSessionModel session) async {
    final id = _uuid.v4();
    await _pendingSessionBox.put(id, session);
    return id;
  }

  List<PendingSessionModel> getAllPendingSessions() {
    return _pendingSessionBox.values.toList();
  }

  List<String> getAllPendingSessionIds() {
    return _pendingSessionBox.keys.cast<String>().toList();
  }

  Map<String, PendingSessionModel> getAllPendingSessionsWithIds() {
    final result = <String, PendingSessionModel>{};
    for (final key in _pendingSessionBox.keys) {
      final value = _pendingSessionBox.get(key);
      if (value != null) {
        result[key.toString()] = value;
      }
    }
    return result;
  }

  Future<void> updatePendingSessionStatus(String id, String status,
      {String? errorMessage, int? retryCount}) async {
    final session = _pendingSessionBox.get(id);
    if (session != null) {
      final updatedSession = session.copyWith(
        status: status,
        errorMessage: errorMessage,
        retryCount: retryCount,
      );
      await _pendingSessionBox.put(id, updatedSession);
    }
  }

  Future<void> deletePendingSession(String id) async {
    await _pendingSessionBox.delete(id);
  }

  Future<void> clearAllPendingSessions() async {
    await _pendingSessionBox.clear();
  }

  // Get pending sessions for a specific user
  List<PendingSessionModel> getPendingSessionsForUser(String userId) {
    return _pendingSessionBox.values
        .where((session) =>
            session.userId == userId && session.status == 'pending')
        .toList();
  }

  // Get failed sessions that need retry
  List<PendingSessionModel> getFailedSessions() {
    return _pendingSessionBox.values
        .where((session) => session.status == 'error' && session.retryCount < 3)
        .toList();
  }
}
