import 'package:get/get.dart';
import 'package:woosh/pages/journeyplan/reports/feedback_report_page.dart';
import 'package:woosh/pages/journeyplan/reports/product_availability_page.dart';
import 'package:woosh/pages/journeyplan/reports/visibility_activity_page.dart';
import 'package:woosh/pages/order/viewOrder/vieworder_page.dart';

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
  ];
}
