import 'package:get/get.dart';
import 'package:woosh/pages/journeyplan/feedback_report_page.dart';
import 'package:woosh/pages/journeyplan/reports/product_availability_page.dart';
import 'package:woosh/pages/journeyplan/reports/visibility_activity_page.dart';
import 'package:woosh/pages/order/viewOrder/vieworder_page.dart';
import 'package:woosh/pages/pos/upliftSaleCart_page.dart';
import 'package:woosh/controllers/uplift_cart_controller.dart';
import 'package:woosh/controllers/uplift_sale_controller.dart';
import 'package:woosh/pages/login/sign_page.dart';
import 'package:woosh/pages/pos/uplift_sales_page.dart';
import 'package:woosh/pages/test/error_test_page.dart';

class AppRoutes {
  static final routes = [
    // Report Routes
    GetPage(
      name: '/journey/reports/feedback',
      page: () => FeedbackReportPage(journeyPlan: Get.arguments['journeyPlan']),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: '/journey/reports/product',
      page: () =>
          ProductAvailabilityPage(journeyPlan: Get.arguments['journeyPlan']),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: '/journey/reports/visibility',
      page: () =>
          VisibilityActivityPage(journeyPlan: Get.arguments['journeyPlan']),
      transition: Transition.rightToLeft,
    ),
    // Orders Route
    GetPage(
      name: '/orders',
      page: () => const ViewOrdersPage(),
      transition: Transition.rightToLeft,
    ),
    // Uplift Product Routes

    GetPage(
      name: '/uplift/cart',
      page: () => UpliftSaleCartPage(
        outlet: Get.arguments['outlet'],
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut<UpliftCartController>(() => UpliftCartController());
      }),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: '/uplift-sales',
      page: () => const UpliftSalesPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut<UpliftSaleController>(() => UpliftSaleController());
      }),
    ),
    GetPage(
      name: '/sign-up',
      page: () => const SignUpPage(),
      transition: Transition.rightToLeft,
    ),
    // Test Route (for development/testing)
    GetPage(
      name: '/test/errors',
      page: () => const ErrorTestPage(),
      transition: Transition.rightToLeft,
    ),
  ];
}
