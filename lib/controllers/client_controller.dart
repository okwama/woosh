import 'package:get/get.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/services/api_service.dart';

class ClientController extends GetxController {
  final RxList<Client> clients = <Client>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentPage = 1.obs;
  final int pageSize = 10;
  int? routeId;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      currentPage.value = 1;
      hasMore.value = true;

      final response = await ApiService.fetchClients(
        routeId: routeId,
        page: currentPage.value,
        limit: pageSize,
      );

      clients.value = response.data;
      hasMore.value = response.page < response.totalPages;
    } catch (e) {
      print('Error loading initial data: $e');
      Get.snackbar(
        'Error',
        'Failed to load clients. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;

    try {
      isLoading.value = true;
      currentPage.value++;

      final response = await ApiService.fetchClients(
        routeId: routeId,
        page: currentPage.value,
        limit: pageSize,
      );

      clients.addAll(response.data);
      hasMore.value = response.page < response.totalPages;
    } catch (e) {
      print('Error loading more data: $e');
      currentPage.value--; // Revert page number on error
      Get.snackbar(
        'Error',
        'Failed to load more clients. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() async {
    await loadInitialData();
  }

  void setRouteId(int? id) {
    routeId = id;
    loadInitialData();
  }
}
