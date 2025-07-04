import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../models/hive/pending_journey_plan_model.dart';

class PendingJourneyPlanHiveService {
  static const String _boxName = 'pendingJourneyPlans';
  late Box<PendingJourneyPlanModel> _pendingJourneyPlanBox;
  final _uuid = const Uuid();

  Future<void> init() async {
    _pendingJourneyPlanBox =
        await Hive.openBox<PendingJourneyPlanModel>(_boxName);
  }

  Future<String> savePendingJourneyPlan(
      PendingJourneyPlanModel journeyPlan) async {
    final id = _uuid.v4();
    await _pendingJourneyPlanBox.put(id, journeyPlan);
    return id;
  }

  List<PendingJourneyPlanModel> getAllPendingJourneyPlans() {
    return _pendingJourneyPlanBox.values.toList();
  }

  List<String> getAllPendingJourneyPlanIds() {
    return _pendingJourneyPlanBox.keys.cast<String>().toList();
  }

  Map<String, PendingJourneyPlanModel> getAllPendingJourneyPlansWithIds() {
    final result = <String, PendingJourneyPlanModel>{};
    for (final key in _pendingJourneyPlanBox.keys) {
      final value = _pendingJourneyPlanBox.get(key);
      if (value != null) {
        result[key.toString()] = value;
      }
    }
    return result;
  }

  Future<void> updatePendingJourneyPlanStatus(String id, String status,
      {String? errorMessage}) async {
    final plan = _pendingJourneyPlanBox.get(id);
    if (plan != null) {
      final updatedPlan = plan.copyWith(
        status: status,
        errorMessage: errorMessage,
      );
      await _pendingJourneyPlanBox.put(id, updatedPlan);
    }
  }

  Future<void> deletePendingJourneyPlan(String id) async {
    await _pendingJourneyPlanBox.delete(id);
  }

  Future<void> clearAllPendingJourneyPlans() async {
    await _pendingJourneyPlanBox.clear();
  }
}
