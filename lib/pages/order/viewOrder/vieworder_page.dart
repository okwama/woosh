import 'package:flutter/material.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/hive/order_model.dart' as hive;
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/user_model.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/pages/order/viewOrder/order_detail.dart';
import 'package:woosh/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/utils/date_utils.dart' as custom_date;
import 'package:woosh/widgets/skeleton_loader.dart';
import 'package:woosh/services/hive/order_hive_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:woosh/utils/country_currency_labels.dart';

class ViewOrdersPage extends StatefulWidget {
  const ViewOrdersPage({super.key});

  @override
  _ViewOrdersPageState createState() => _ViewOrdersPageState();
}

class _ViewOrdersPageState extends State<ViewOrdersPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Order> _orders = [];
  int _page = 1;
  static const int _limit = 10;
  bool _hasMore = true;
  static const int _prefetchThreshold = 200;
  static const int _precachePages = 2; // Number of pages to precache

  final currencyFormat = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 2,
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _prefetchThreshold) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
      _orders = [];
    });

    try {
      print('[ViewOrders Debug] Loading orders...');

      // Load initial page
      final response = await _retryApiCall(
        () => ApiService.getOrders(page: 1, limit: _limit),
        maxRetries: 3,
        timeout: const Duration(seconds: 15),
      );

      print(
          '[ViewOrders Debug] Response received: ${response.data.isNotEmpty}');
      print('[ViewOrders Debug] Total orders: ${response.total}');
      print('[ViewOrders Debug] Page: ${response.page}');
      print('[ViewOrders Debug] Total pages: ${response.totalPages}');
      print('[ViewOrders Debug] Orders count: ${response.data.length}');

      // Debug client data for first few orders
      for (int i = 0; i < response.data.length && i < 3; i++) {
        final order = response.data[i];
        print(
            '[ViewOrders Debug] Order ${order.id} - Client: ${order.client.name} (ID: ${order.client.id})');
        print(
            '[ViewOrders Debug] Order ${order.id} - Client address: ${order.client.address}');
      }

      if (mounted) {
        setState(() {
          _orders = response.data;
          _isLoading = false;
          _hasMore = response.page < response.totalPages;
        });

        // Precache next pages if available
        if (_hasMore) {
          _precacheNextPages();
        }
      }
    } catch (e) {
      print('[ViewOrders Debug] Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Auto-retry after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadOrders();
        });
      }
    }
  }

  Future<void> _precacheNextPages() async {
    if (!_hasMore) return;

    final nextPage = _page + 1;
    final endPage = nextPage + _precachePages;

    for (int page = nextPage; page < endPage; page++) {
      try {
        final response = await _retryApiCall(
          () => ApiService.getOrders(page: page, limit: _limit),
          maxRetries: 2,
          timeout: const Duration(seconds: 10),
        );

        if (mounted && response.data.isNotEmpty) {
          // Cache the data for future use
          ApiService.cacheData(
            'orders_page_$page',
            response.data,
            validity: const Duration(minutes: 5),
          );
        }
      } catch (e) {
        // Silently fail for precaching
        print('Precaching failed for page $page: $e');
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Try to get cached data first
      final cachedData =
          ApiService.getCachedData<List<Order>>('orders_page_${_page + 1}');

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _orders.addAll(cachedData);
            _page++;
            _isLoadingMore = false;
            _hasMore = _page <
                _precachePages +
                    1; // Check if we've reached the precached limit
          });
        }
        return;
      }

      // If no cached data, fetch from API
      final response = await _retryApiCall(
        () => ApiService.getOrders(page: _page + 1, limit: _limit),
        maxRetries: 3,
        timeout: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _orders.addAll(response.data);
          _page++;
          _isLoadingMore = false;
          _hasMore = response.page < response.totalPages;
        });

        // Precache next pages if available
        if (_hasMore) {
          _precacheNextPages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        // Auto-retry after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadMoreOrders();
        });
      }
    }
  }

  Future<T> _retryApiCall<T>(
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await apiCall().timeout(timeout);
      } catch (e) {
        if (attempts >= maxRetries) {
          rethrow;
        }
        print('Retry attempt $attempts of $maxRetries after error: $e');
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }
  }

  Future<void> _refreshOrders() async {
    try {
      // Show loading indicator without clearing existing data
      setState(() {
        _isLoading = true;
      });

      // Clear existing cache before refresh
      for (int i = 1; i <= _precachePages; i++) {
        ApiService.removeFromCache('orders_page_$i');
      }

      // Reset pagination state but keep existing orders
      _page = 1;
      _hasMore = true;

      // Load fresh data
      final response = await _retryApiCall(
        () => ApiService.getOrders(page: 1, limit: _limit),
        maxRetries: 3,
        timeout: const Duration(seconds: 15),
      );

      // Update with new data only after successfully loading
      if (mounted) {
        setState(() {
          _orders = response.data;
          _isLoading = false;
          _hasMore = response.page < response.totalPages;
        });

        // Precache next pages if available
        if (_hasMore) {
          _precacheNextPages();
        }
      }

      // Show success feedback
      if (mounted) {
        Get.snackbar(
          'Success',
          'Orders refreshed successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to refresh orders',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // Refresh only a specific order by its ID without clearing the screen
  Future<void> _refreshSingleOrder(int orderId) async {
    try {
      // Find the current index of the order to update
      final currentIndex = _orders.indexWhere((o) => o.id == orderId);
      if (currentIndex == -1) return; // Order not found in list

      // Store a reference to the current order for comparison later
      final currentOrder = _orders[currentIndex];

      // Use the existing getOrders API with a small limit
      // This is more efficient than reloading all orders
      final response = await _retryApiCall(
        () => ApiService.getOrders(page: 1, limit: 20),
        maxRetries: 2,
        timeout: const Duration(seconds: 10),
      );

      // Find the updated order in the response
      final updatedOrder = response.data.firstWhere(
        (o) => o.id == orderId,
        orElse: () => currentOrder, // Keep current if not found
      );

      // Update only this order in the list if it's different
      if (mounted && updatedOrder != currentOrder) {
        setState(() {
          _orders[currentIndex] = updatedOrder;
        });
      }
    } catch (e) {
      // Handle error silently - the old data is still valid
      print('Error refreshing order $orderId: $e');
    }
  }

  // Helper method to check if order can be deleted
  bool _canDeleteOrder(Order order) {
    final canDelete = order.status == OrderStatus.DRAFT;
    print(
        '[Delete Debug] Order ${order.id} - Status: ${order.status} - Can delete: $canDelete');
    return canDelete;
  }

  Future<void> _deleteOrder(Order order) async {
    try {
      // Check if order can be deleted
      if (!_canDeleteOrder(order)) {
        Get.snackbar(
          'Cannot Delete Order',
          'Only draft orders can be deleted. Current status: ${order.status}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this order?'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Status: ${order.status}'),
                    Text('Client: ${order.client.name}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final result = await ApiService.deleteOrder(order.id);
        if (result) {
          Get.snackbar(
            'Success',
            'Order deleted successfully',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          _refreshOrders();
        }
      }
    } catch (e) {
      String errorMessage = 'Failed to delete order';

      // Handle specific API error messages
      if (e.toString().contains('Cannot delete order with status')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else if (e.toString().contains('Order not found')) {
        errorMessage =
            'Order not found or you do not have permission to delete it';
      }

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'draft':
        return Colors.orange;
      case 'confirmed':
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'voided':
        return Colors.red;
      case 'shipped':
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'My Orders',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Show loading indicator in app bar
              setState(() {
                _isLoading = true;
              });
              _refreshOrders().then((_) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading && _orders.isEmpty
          ? const OrdersListSkeleton()
          : RefreshIndicator(
              onRefresh: _refreshOrders,
              color: Theme.of(context).primaryColor,
              backgroundColor: Colors.white,
              strokeWidth: 2.0,
              displacement: 40.0,
              edgeOffset: 0.0,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _orders.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_basket_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const Text('No orders found'),
                                ],
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == _orders.length) {
                                  return _isLoadingMore
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                }

                                final order = _orders[index];
                                final firstItem = order.orderItems.isNotEmpty
                                    ? order.orderItems.first
                                    : null;
                                final totalItems = order.orderItems.length;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                    elevation: 1,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        // Navigate to order detail and refresh on return if needed
                                        final future = Get.to(
                                          () => OrderDetailPage(
                                            order: hive.OrderModel(
                                              id: order.id,
                                              clientId: order.client.id,
                                              orderNumber: order.id.toString(),
                                              orderDate: order.createdAt,
                                              totalAmount:
                                                  order.totalAmount ?? 0.0,
                                              status: order.status
                                                  .toString()
                                                  .split('.')
                                                  .last,
                                              items: order.orderItems
                                                  .map((item) =>
                                                      hive.OrderItemModel(
                                                        id: item.id ?? 0,
                                                        productId:
                                                            item.product?.id ??
                                                                0,
                                                        productName: item
                                                                .product
                                                                ?.productName ??
                                                            'Unknown Product',
                                                        quantity: item.quantity,
                                                        unitPrice:
                                                            (item.unitPrice ??
                                                                    0.0)
                                                                .toDouble(),
                                                      ))
                                                  .toList(),
                                            ),
                                          ),
                                          transition: Transition.rightToLeft,
                                        );

                                        // Use null-safe then() to handle the result
                                        future?.then((result) {
                                          // Refresh only the specific order if an update was made
                                          if (result == true) {
                                            _refreshSingleOrder(order.id);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    'Order #${order.id}',
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      custom_date.DateUtils
                                                          .formatDateTime(
                                                              order.createdAt),
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    // Delete button for draft orders
                                                    if (_canDeleteOrder(
                                                        order)) ...[
                                                      const SizedBox(width: 8),
                                                      Tooltip(
                                                        message:
                                                            'Delete draft order',
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              _deleteOrder(
                                                                  order),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.red
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 16,
                                                              color: Colors
                                                                  .red.shade600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Client: ${order.client.name.isNotEmpty ? order.client.name : 'Unknown Client'}',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color.fromARGB(
                                                              255, 4, 4, 4),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                      if (order.client.address
                                                              ?.isNotEmpty ??
                                                          false)
                                                        Text(
                                                          order.client
                                                                  .address ??
                                                              '',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Amount: ${CountryCurrencyLabels.formatCurrency(order.totalAmount ?? 0.0, null)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                                order.status
                                                                    .toString()
                                                                    .split('.')
                                                                    .last)
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            order.status
                                                                .toString()
                                                                .split('.')
                                                                .last
                                                                .toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: _getStatusColor(
                                                                  order.status
                                                                      .toString()
                                                                      .split(
                                                                          '.')
                                                                      .last),
                                                            ),
                                                          ),
                                                          // Show delete indicator for draft orders
                                                          if (_canDeleteOrder(
                                                              order)) ...[
                                                            const SizedBox(
                                                                width: 4),
                                                            Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 10,
                                                              color: Colors
                                                                  .red.shade600,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey
                                                    .withOpacity(0.05),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        totalItems > 1
                                                            ? '+${totalItems - 1} more items'
                                                            : '1 item',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _orders.length + (_hasMore ? 1 : 0),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
