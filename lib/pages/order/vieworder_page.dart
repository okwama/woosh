// View Order Page
import 'package:flutter/material.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/orderitem_model.dart'; // Add this import
import 'package:woosh/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:get/get.dart';

class ViewOrdersPage extends StatefulWidget {
  const ViewOrdersPage({super.key});

  @override
  _ViewOrdersPageState createState() => _ViewOrdersPageState();
}

class _ViewOrdersPageState extends State<ViewOrdersPage> {
  bool _isLoading = false;
  List<Order> _orders = [];
  String? _error;
  int _page = 1;
  static const int _limit = 10;
  bool _hasMore = true;
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _loadOrders(page: _page + 1);
      }
    }
  }

  Future<void> _loadOrders({int? page}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (page == 1) {
        _orders = [];
      }
    });

    try {
      final response = await ApiService.getOrders(
        page: page ?? _page,
        limit: _limit,
      );

      setState(() {
        if (page == 1) {
          _orders = response.data;
        } else {
          _orders.addAll(response.data);
        }
        _page = page ?? _page;
        _hasMore = response.page < response.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() {
    _page = 1;
    return _loadOrders(page: 1);
  }

  Future<void> _deleteOrder(Order order) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Order'),
          content: const Text('Are you sure you want to delete this order?'),
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
        } else {
          Get.snackbar(
            'Warning',
            'Order was not deleted',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      String errorMessage = 'Failed to delete order';

      // Check for specific error types
      if (e.toString().contains('404') || e.toString().contains('Not found')) {
        errorMessage = 'Order not found or already deleted';
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        errorMessage = 'Authorization error. Please login again';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Check your connection';
      }

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // If order not found, refresh the list anyway
      if (errorMessage.contains('not found')) {
        _refreshOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _error != null && _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshOrders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshOrders,
              child: _orders.isEmpty && _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                      ? Center(
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
                        )
                      : ListView.builder(
                          key: const PageStorageKey('orders_list'),
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _orders.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _orders.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final order = _orders[index];
                            // Get the first order item to display as main product
                            final firstOrderItem = order.orderItems.isNotEmpty
                                ? order.orderItems.first
                                : null;

                            return Card(
                              key: ValueKey('order_${order.id}_$index'),
                              child: ListTile(
                                title: Text(firstOrderItem?.product?.name ??
                                    'No products'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Outlet: ${order.outlet.name}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Total Items: ${order.orderItems.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddOrderPage(
                                              outlet: order.outlet,
                                              order: order,
                                            ),
                                          ),
                                        ).then((result) {
                                          if (result == true) {
                                            _refreshOrders();
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteOrder(order),
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
