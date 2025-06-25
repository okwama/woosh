import 'package:get/get.dart';
import 'package:glamour_queen/models/report/productReport_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/productTransaction_service.dart';

enum ProductType {
  RETURN,
  SAMPLE,
}

class ProductReportController extends GetxController {
  final RxList<ProductReport> productReports = <ProductReport>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Future<void> loadProductReports({
    ProductType? type, // Filter by type (RETURN or SAMPLE)
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? clientId,
    int? userId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ProductTransactionService.getProductReports(
        type: type?.toString().split('.').last, // Convert enum to string
        status: status,
        startDate: startDate,
        endDate: endDate,
        clientId: clientId,
        userId: userId,
      );

      productReports.value = response;
        } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ProductReport?> getProductReportById(int id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await ProductTransactionService.getProductReportById(id);
      return response;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateProductReportStatus(int id, String status) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final success = await ProductTransactionService.updateProductReportStatus(id, status);
      if (success) {
        // Update local state
        final index = productReports.indexWhere((report) => report.id == id);
        if (index != -1) {
          final updatedReport = await getProductReportById(id);
          if (updatedReport != null) {
            productReports[index] = updatedReport;
          }
        }
      }
      return success;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteProductReport(int id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final success = await ProductTransactionService.deleteProductReport(id);
      if (success) {
        productReports.removeWhere((report) => report.id == id);
      }
      return success;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

