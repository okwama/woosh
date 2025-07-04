import 'package:get/get.dart';

class SessionState extends GetxController {
  final isSessionActive = false.obs;
  final sessionStartTime = Rxn<DateTime>();

  void updateSessionState(bool active, DateTime? startTime) {
    isSessionActive.value = active;
    sessionStartTime.value = startTime;
  }

  bool canAccessFeature() {
    return isSessionActive.value;
  }

  bool isSessionExpired() {
    if (sessionStartTime.value == null) return true;
    final now = DateTime.now();
    return now.difference(sessionStartTime.value!).inHours >= 9; // 9-hour shift
  }
}
