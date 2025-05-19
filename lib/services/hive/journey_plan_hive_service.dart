import 'package:hive/hive.dart';
import '../../models/hive/journey_plan_model.dart';

class JourneyPlanHiveService {
  static const String _boxName = 'journeyPlans';
  late Box<JourneyPlanModel> _journeyPlanBox;

  Future<void> init() async {
    _journeyPlanBox = await Hive.openBox<JourneyPlanModel>(_boxName);
  }

  Future<void> saveJourneyPlan(JourneyPlanModel journeyPlan) async {
    await _journeyPlanBox.put(journeyPlan.id, journeyPlan);
  }

  Future<void> saveJourneyPlans(List<JourneyPlanModel> journeyPlans) async {
    final Map<int, JourneyPlanModel> journeyPlanMap = {
      for (var plan in journeyPlans) plan.id: plan
    };
    await _journeyPlanBox.putAll(journeyPlanMap);
  }

  JourneyPlanModel? getJourneyPlan(int id) {
    return _journeyPlanBox.get(id);
  }

  List<JourneyPlanModel> getAllJourneyPlans() {
    return _journeyPlanBox.values.toList();
  }

  List<JourneyPlanModel> getJourneyPlansByDate(DateTime date) {
    return _journeyPlanBox.values
        .where((plan) =>
            plan.date.year == date.year &&
            plan.date.month == date.month &&
            plan.date.day == date.day)
        .toList();
  }

  Future<void> deleteJourneyPlan(int id) async {
    await _journeyPlanBox.delete(id);
  }

  Future<void> clearAllJourneyPlans() async {
    await _journeyPlanBox.clear();
  }
}
