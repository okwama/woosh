import 'package:flutter/material.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/pages/order/viewOrder/orderDetail.dart';
import 'package:woosh/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/utils/date_utils.dart';

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
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete order',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'My Orders',
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
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _orders.isEmpty && _isLoading
                        ? const SliverToBoxAdapter(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _orders.isEmpty
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
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    final order = _orders[index];
                                    final firstItem =
                                        order.orderItems.isNotEmpty
                                            ? order.orderItems.first
                                            : null;
                                    final totalItems = order.orderItems.length;
                                    // final totalPrice = order.orderItems.fold(
                                    //     0.0,
                                    //     (sum, item) =>
                                    //         sum +
                                    //         (item.product?.price ?? 0) *
                                    //             item.quantity);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Material(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                        elevation: 2,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            Get.to(
                                              () =>
                                                  OrderDetailPage(order: order),
                                              transition:
                                                  Transition.rightToLeft,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Header with status and date
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        'Order #${order.id}',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormatter
                                                          .formatDateTime(
                                                              order.createdAt),
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '${order.client.name}',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Color.fromARGB(
                                                            255, 4, 4, 4),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // Main product preview
                                                // if (firstItem != null)
                                                //   Row(
                                                //     children: [
                                                //       Container(
                                                //         width: 60,
                                                //         height: 60,
                                                //         decoration: BoxDecoration(
                                                //           color: Colors.grey
                                                //               .shade200,
                                                //           borderRadius:
                                                //               BorderRadius
                                                //                   .circular(8),
                                                //         ),
                                                //         child: Icon(
                                                //           Icons.shopping_bag,
                                                //           color: Theme.of(
                                                //                   context)
                                                //               .primaryColor,
                                                //         ),
                                                //       ),
                                                //       const SizedBox(width: 12),
                                                //       Expanded(
                                                //         child: Column(
                                                //           crossAxisAlignment:
                                                //               CrossAxisAlignment
                                                //                   .start,
                                                //           children: [
                                                //             Text(
                                                //               firstItem.product
                                                //                       ?.name ??
                                                //                   'Product',
                                                //               style:
                                                //                   const TextStyle(
                                                //                 fontWeight:
                                                //                     FontWeight
                                                //                         .w500,
                                                //               ),
                                                //             ),
                                                //             const SizedBox(
                                                //                 height: 4),
                                                //             Text(
                                                //               '${firstItem.quantity} × \Ksh ${firstItem.product?.price.toStringAsFixed(2) ?? '0.00'}',
                                                //               style:
                                                //                   const TextStyle(
                                                //                 color: Colors
                                                //                     .grey,
                                                //                 fontSize: 12,
                                                //               ),
                                                //             ),
                                                //           ],
                                                //         ),
                                                //       ),
                                                //     ],
                                                //   ),
                                                const SizedBox(height: 12),
                                                // Order summary
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey
                                                        .withOpacity(0.05),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
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
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          // Text(
                                                          //   order.outlet.name,
                                                          //   style: const TextStyle(
                                                          //       fontSize: 12,
                                                          //       color:
                                                          //           Color.fromARGB(255, 4, 4, 4)),
                                                          // ),
                                                        ],
                                                      ),
                                                      // Text(
                                                      //   currencyFormat.format(totalPrice),
                                                      //   style: TextStyle(
                                                      //     fontWeight:
                                                      //         FontWeight.bold,
                                                      //     color: Theme.of(
                                                      //             context)
                                                      //         .primaryColor,
                                                      //   ),
                                                      // ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Action buttons
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    // TextButton(
                                                    //   onPressed: () =>
                                                    //       _deleteOrder(order),
                                                    //   style: TextButton.styleFrom(
                                                    //     foregroundColor:
                                                    //         Colors.red,
                                                    //   ),
                                                    //   child: const Text('Delete'),
                                                    // ),
                                                    const SizedBox(width: 8),
                                                    // ElevatedButton(
                                                    //   onPressed: () {
                                                    //     Get.to(
                                                    //       () => OrderDetailPage(
                                                    //           order: order),
                                                    //       transition: Transition
                                                    //           .rightToLeft,
                                                    //     );
                                                    //   },
                                                    //   style: ElevatedButton
                                                    //       .styleFrom(
                                                    //     backgroundColor: Theme.of(
                                                    //             context)
                                                    //         .primaryColor,
                                                    //   ),
                                                    //   child: const Text(
                                                    //       'View Details',
                                                    //       style: TextStyle(
                                                    //           color:
                                                    //               Colors.white)),
                                                    // ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  childCount:
                                      _orders.length + (_hasMore ? 1 : 0),
                                ),
                              ),
                  ),
                  if (_hasMore && _orders.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
