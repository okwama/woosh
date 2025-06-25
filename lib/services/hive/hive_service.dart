import 'package:hive_flutter/hive_flutter.dart';
import 'package:glamour_queen/models/hive/session_model.dart';

class HiveService {
  static Future<void> init() async {
    // Initialize Hive
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(SessionModelAdapter());

    // Open boxes
    await Hive.openBox<SessionModel>('sessionBox');
  }
}

