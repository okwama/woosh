import 'package:hive/hive.dart';
import 'package:woosh/models/hive/product_report_hive_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/product_report_model.dart';
import 'package:woosh/models/report/report_model.dart';

class ProductReportHiveService {
  static const String _boxName = 'productReports';
  late Box<ProductReportHiveModel> _productReportBox;
  bool _isInitialized = false;

  Future<void> init() async {
    try {
      _productReportBox = await Hive.openBox<ProductReportHiveModel>(_boxName);
      _isInitialized = true;
    } catch (e) {
      print('⚠️ Error initializing ProductReportHiveService: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // Helper method to check if the service is ready
  bool get isReady => _isInitialized && _productReportBox.isOpen;

  // Helper method to ensure the service is initialized
  void _ensureInitialized() {
    if (!isReady) {
      throw StateError(
          'ProductReportHiveService is not initialized. Call init() first.');
    }
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
    _ensureInitialized();

    final productQuantities = products
        .where((product) =>
            quantities[product.id] != null && quantities[product.id]! > 0)
        .map((product) => ProductQuantityHiveModel(
              productId: product.id,
              productName: product.productName,
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
    _ensureInitialized();
    return _productReportBox.values
        .where((report) => !report.isSynced)
        .toList();
  }

  // Get a product report by journey plan ID
  ProductReportHiveModel? getReportByJourneyPlanId(int journeyPlanId) {
    _ensureInitialized();
    return _productReportBox.get(journeyPlanId);
  }

  // Get the most recent report for a specific client
  ProductReportHiveModel? getRecentReportByClientId(int clientId) {
    _ensureInitialized();
    final reports = _productReportBox.values
        .where((report) => report.clientId == clientId)
        .toList();

    if (reports.isEmpty) return null;

    // Sort by creation date and return the most recent
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports.first;
  }

  // Mark a report as synchronized with the server
  Future<void> markAsSynced(int journeyPlanId) async {
    _ensureInitialized();
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
    _ensureInitialized();
    await _productReportBox.delete(journeyPlanId);
  }

  // Convert a Hive model to a Report model for API submission
  Report convertToReportModel(
      ProductReportHiveModel hiveModel, int salesRepId) {
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
    _ensureInitialized();
    await _productReportBox.clear();
  }
}
