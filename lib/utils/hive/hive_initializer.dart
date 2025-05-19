import 'package:hive_flutter/hive_flutter.dart';
import 'package:woosh/models/hive/client_model.dart';
import 'package:woosh/models/hive/journey_plan_model.dart';
import 'package:woosh/models/hive/order_model.dart';
import 'package:woosh/models/hive/user_model.dart';
import 'package:woosh/models/hive/session_model.dart';

class HiveInitializer {
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(OrderModelAdapter());
    Hive.registerAdapter(OrderItemModelAdapter());
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(ClientModelAdapter());
    Hive.registerAdapter(JourneyPlanModelAdapter());
    Hive.registerAdapter(SessionModelAdapter());

    // Open boxes
    await Hive.openBox<OrderModel>('orders');
    await Hive.openBox<UserModel>('users');
    await Hive.openBox<ClientModel>('clients');
    await Hive.openBox<JourneyPlanModel>('journey_plans');
    await Hive.openBox<SessionModel>('sessionBox');
  }
}
