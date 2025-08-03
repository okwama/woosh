import 'package:hive_flutter/hive_flutter.dart';
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

class HiveInitializer {
  /// Minimal initialization for faster startup
  static Future<void> initializeMinimal() async {
    await Hive.initFlutter();

    // Register only essential adapters with correct typeIds
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SessionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ProductReportHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ProductQuantityHiveModelAdapter());
    }

    // Open only essential boxes with proper error handling
    try {
      if (!Hive.isBoxOpen('users')) {
        await Hive.openBox<UserModel>('users');
      }
      if (!Hive.isBoxOpen('sessionBox')) {
        await Hive.openBox<SessionModel>('sessionBox');
      }
      if (!Hive.isBoxOpen('productReports')) {
        await Hive.openBox<ProductReportHiveModel>('productReports');
      }
      if (!Hive.isBoxOpen('timestamps')) {
        await Hive.openBox('timestamps');
      }
    } catch (e) {
      print('⚠️ Error opening Hive boxes: $e');
    }

    print('✅ Hive minimal initialization completed');
  }

  /// Clear all Hive boxes to resolve schema conflicts
  static Future<void> clearAllBoxes() async {
    try {
      final boxNames = [
        'orders',
        'users',
        'clients',
        'journeyPlans',
        'sessionBox',
        'routes',
        'pendingJourneyPlans',
        'productReports',
        'products',
        'pendingSessions',
        'timestamps'
      ];

      for (final boxName in boxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.close();
          }
          await Hive.deleteBoxFromDisk(boxName);
        } catch (e) {
          print('⚠️ Error clearing box $boxName: $e');
          // Continue with other boxes even if one fails
        }
      }

      print('✅ All Hive boxes cleared successfully');
    } catch (e) {
      print('⚠️ Error clearing Hive boxes: $e');
    }
  }

  /// Full initialization for complete functionality
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters with correct typeIds based on model definitions
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(OrderModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OrderItemModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ClientModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(JourneyPlanModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SessionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(PendingJourneyPlanModelAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ProductReportHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ProductQuantityHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(ProductHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(PendingSessionModelAdapter());
    }

    // Open boxes with proper error handling
    try {
      if (!Hive.isBoxOpen('orders')) {
        await Hive.openBox<OrderModel>('orders');
      }
      if (!Hive.isBoxOpen('users')) {
        await Hive.openBox<UserModel>('users');
      }
      if (!Hive.isBoxOpen('clients')) {
        await Hive.openBox<ClientModel>('clients');
      }
      if (!Hive.isBoxOpen('journeyPlans')) {
        await Hive.openBox<JourneyPlanModel>('journeyPlans');
      }
      if (!Hive.isBoxOpen('sessionBox')) {
        await Hive.openBox<SessionModel>('sessionBox');
      }
      if (!Hive.isBoxOpen('pendingJourneyPlans')) {
        await Hive.openBox<PendingJourneyPlanModel>('pendingJourneyPlans');
      }
      if (!Hive.isBoxOpen('productReports')) {
        await Hive.openBox<ProductReportHiveModel>('productReports');
      }
      if (!Hive.isBoxOpen('products')) {
        await Hive.openBox<ProductHiveModel>('products');
      }
      if (!Hive.isBoxOpen('pendingSessions')) {
        await Hive.openBox<PendingSessionModel>('pendingSessions');
      }
      if (!Hive.isBoxOpen('timestamps')) {
        await Hive.openBox('timestamps');
      }
    } catch (e) {
      print('⚠️ Error opening Hive boxes: $e');
    }

    // Initialize and register Hive services
    try {
      final clientHiveService = ClientHiveService();
      await clientHiveService.init();
      Get.put(clientHiveService);

      final journeyPlanHiveService = JourneyPlanHiveService();
      await journeyPlanHiveService.init();
      Get.put(journeyPlanHiveService);

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
    } catch (e) {
      print('⚠️ Error initializing Hive services: $e');
    }

    print('✅ Hive full initialization completed');
  }

  /// Complete initialization in background
  static Future<void> initializeRemaining() async {
    try {
      // Register remaining adapters with correct typeIds
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OrderModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(OrderItemModelAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ClientModelAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(JourneyPlanModelAdapter());
      }
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(PendingJourneyPlanModelAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ProductHiveModelAdapter());
      }
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(PendingSessionModelAdapter());
      }

      // Open remaining boxes with proper error handling
      try {
        if (!Hive.isBoxOpen('orders')) {
          await Hive.openBox<OrderModel>('orders');
        }
        if (!Hive.isBoxOpen('clients')) {
          await Hive.openBox<ClientModel>('clients');
        }
        if (!Hive.isBoxOpen('journeyPlans')) {
          await Hive.openBox<JourneyPlanModel>('journeyPlans');
        }
        if (!Hive.isBoxOpen('pendingJourneyPlans')) {
          await Hive.openBox<PendingJourneyPlanModel>('pendingJourneyPlans');
        }
        if (!Hive.isBoxOpen('products')) {
          await Hive.openBox<ProductHiveModel>('products');
        }
        if (!Hive.isBoxOpen('pendingSessions')) {
          await Hive.openBox<PendingSessionModel>('pendingSessions');
        }
      } catch (e) {
        print('⚠️ Error opening remaining Hive boxes: $e');
      }

      // Initialize and register Hive services
      try {
        final clientHiveService = ClientHiveService();
        await clientHiveService.init();
        Get.put(clientHiveService);

        final journeyPlanHiveService = JourneyPlanHiveService();
        await journeyPlanHiveService.init();
        Get.put(journeyPlanHiveService);

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
      } catch (e) {
        print('⚠️ Error initializing remaining Hive services: $e');
      }

      print('✅ Hive remaining initialization completed');
    } catch (e) {
      print('⚠️ Hive remaining initialization failed: $e');
    }
  }
}
