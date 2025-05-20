import 'package:hive/hive.dart';
import 'package:woosh/models/hive/product_report_hive_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/models/report/report_model.dart';

class ProductReportHiveService {
  static const String _boxName = 'productReports';
  late Box<ProductReportHiveModel> _productReportBox;

  Future<void> init() async {
    _productReportBox = await Hive.openBox<ProductReportHiveModel>(_boxName);
  }

  // Save a product report to Hive
  Future<void> saveProductReport({
    required int journeyPlanId,
    required int clientId,
    required String clientName,
    required String clientAddress,
    required List<Product> products,
    required Map<int, int> quantities,
    String comment = '',
  }) async {
    final productQuantities = products
        .where((product) => quantities[product.id] != null && quantities[product.id]! > 0)
        .map((product) => ProductQuantityHiveModel(
              productId: product.id,
              productName: product.name,
              quantity: quantities[product.id] ?? 0,
            ))
        .toList();

    if (productQuantities.isEmpty) {
      return; // Don't save if no products have quantities
    }

    final productReport = ProductReportHiveModel(
      journeyPlanId: journeyPlanId,
      clientId: clientId,
      clientName: clientName,
      clientAddress: clientAddress,
      products: productQuantities,
      comment: comment,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    // Use journeyPlanId as key to ensure we only have one report per journey plan
    await _productReportBox.put(journeyPlanId, productReport);
  }

  // Get all unsynchronized product reports
  List<ProductReportHiveModel> getUnsyncedReports() {
    return _productReportBox.values.where((report) => !report.isSynced).toList();
  }

  // Get a product report by journey plan ID
  ProductReportHiveModel? getReportByJourneyPlanId(int journeyPlanId) {
    return _productReportBox.get(journeyPlanId);
  }

  // Mark a report as synchronized with the server
  Future<void> markAsSynced(int journeyPlanId) async {
    final report = _productReportBox.get(journeyPlanId);
    if (report != null) {
      final updatedReport = ProductReportHiveModel(
        journeyPlanId: report.journeyPlanId,
        clientId: report.clientId,
        clientName: report.clientName,
        clientAddress: report.clientAddress,
        products: report.products,
        comment: report.comment,
        createdAt: report.createdAt,
        isSynced: true,
      );
      await _productReportBox.put(journeyPlanId, updatedReport);
    }
  }

  // Delete a report
  Future<void> deleteReport(int journeyPlanId) async {
    await _productReportBox.delete(journeyPlanId);
  }

  // Convert a Hive model to a Report model for API submission
  Report convertToReportModel(ProductReportHiveModel hiveModel, int salesRepId) {
    final productReports = hiveModel.products
        .map((product) => ProductReport(
              reportId: 0,
              productId: product.productId,
              productName: product.productName,
              quantity: product.quantity,
              comment: hiveModel.comment,
            ))
        .toList();

    return Report(
      type: ReportType.PRODUCT_AVAILABILITY,
      journeyPlanId: hiveModel.journeyPlanId,
      salesRepId: salesRepId,
      clientId: hiveModel.clientId,
      productReports: productReports,
    );
  }

  // Clear all reports
  Future<void> clearAllReports() async {
    await _productReportBox.clear();
  }
}
