// View Order Page
import 'package:flutter/material.dart';
import 'package:whoosh/models/order_model.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/pages/order/addorder_page.dart';

class ViewOrdersPage extends StatefulWidget {
  const ViewOrdersPage({Key? key}) : super(key: key);

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
                            return Card(
                              child: ListTile(
                                title: Text(order.product.name),
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
                                      'Quantity: ${order.quantity}',
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
                                trailing: IconButton(
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
                              ),
                            );
                          },
                        ),
            ),
    );

  }}