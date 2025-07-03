import 'package:hive_flutter/hive_flutter.dart';
<<<<<<< HEAD
import 'package:woosh/models/hive/client_model.dart';
import 'package:woosh/models/hive/journey_plan_model.dart';
import 'package:woosh/models/hive/order_model.dart';
import 'package:woosh/models/hive/user_model.dart';
import 'package:woosh/models/hive/session_model.dart';
import 'package:woosh/models/hive/route_model.dart';
import 'package:woosh/models/hive/pending_journey_plan_model.dart';
import 'package:woosh/models/hive/product_report_hive_model.dart';
import 'package:woosh/models/hive/product_model.dart';
import 'package:woosh/models/hive/pending_session_model.dart';
import 'package:get/get.dart';
import 'package:woosh/services/hive/client_hive_service.dart';
import 'package:woosh/services/hive/journey_plan_hive_service.dart';
import 'package:woosh/services/hive/route_hive_service.dart';
import 'package:woosh/services/hive/pending_journey_plan_hive_service.dart';
import 'package:woosh/services/hive/product_report_hive_service.dart';
import 'package:woosh/services/hive/product_hive_service.dart';
import 'package:woosh/services/hive/order_hive_service.dart';
import 'package:woosh/services/hive/pending_session_hive_service.dart';
=======
import 'package:glamour_queen/models/hive/client_model.dart';
import 'package:glamour_queen/models/hive/journey_plan_model.dart';
import 'package:glamour_queen/models/hive/order_model.dart';
import 'package:glamour_queen/models/hive/user_model.dart';
import 'package:glamour_queen/models/hive/session_model.dart';
import 'package:glamour_queen/models/hive/route_model.dart';
import 'package:glamour_queen/models/hive/pending_journey_plan_model.dart';
import 'package:glamour_queen/models/hive/product_report_hive_model.dart';
import 'package:glamour_queen/models/hive/product_model.dart';
import 'package:get/get.dart';
import 'package:glamour_queen/services/hive/client_hive_service.dart';
import 'package:glamour_queen/services/hive/journey_plan_hive_service.dart';
import 'package:glamour_queen/services/hive/route_hive_service.dart';
import 'package:glamour_queen/services/hive/pending_journey_plan_hive_service.dart';
import 'package:glamour_queen/services/hive/product_report_hive_service.dart';
import 'package:glamour_queen/services/hive/product_hive_service.dart';
import 'package:glamour_queen/services/hive/order_hive_service.dart';
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

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
    Hive.registerAdapter(RouteModelAdapter());
    Hive.registerAdapter(PendingJourneyPlanModelAdapter());
    Hive.registerAdapter(ProductReportHiveModelAdapter());
    Hive.registerAdapter(ProductQuantityHiveModelAdapter());
    Hive.registerAdapter(ProductHiveModelAdapter());
    Hive.registerAdapter(PendingSessionModelAdapter());

    // Open boxes
    await Hive.openBox<OrderModel>('orders');
    await Hive.openBox<UserModel>('users');
    await Hive.openBox<ClientModel>('clients');
    await Hive.openBox<JourneyPlanModel>('journeyPlans');
    await Hive.openBox<SessionModel>('sessionBox');
    await Hive.openBox<RouteModel>('routes');
    await Hive.openBox<PendingJourneyPlanModel>('pendingJourneyPlans');
    await Hive.openBox<ProductReportHiveModel>('productReports');
    await Hive.openBox<ProductHiveModel>('products');
    await Hive.openBox<PendingSessionModel>('pendingSessions');

    // Open general timestamp box for tracking last update times
    await Hive.openBox('timestamps');

    // Initialize and register Hive services
    final clientHiveService = ClientHiveService();
    await clientHiveService.init();
    Get.put(clientHiveService);

    final journeyPlanHiveService = JourneyPlanHiveService();
    await journeyPlanHiveService.init();
    Get.put(journeyPlanHiveService);

    final routeHiveService = RouteHiveService();
    await routeHiveService.init();
    Get.put(routeHiveService);

    final pendingJourneyPlanHiveService = PendingJourneyPlanHiveService();
    await pendingJourneyPlanHiveService.init();
    Get.put(pendingJourneyPlanHiveService);

    final productReportHiveService = ProductReportHiveService();
    await productReportHiveService.init();
    Get.put(productReportHiveService);

    final productHiveService = ProductHiveService();
    await productHiveService.init();
    Get.put(productHiveService);

    final orderHiveService = OrderHiveService();
    await orderHiveService.init();
    Get.put(orderHiveService);

    final pendingSessionHiveService = PendingSessionHiveService();
    await pendingSessionHiveService.init();
    Get.put(pendingSessionHiveService);
  }
}

