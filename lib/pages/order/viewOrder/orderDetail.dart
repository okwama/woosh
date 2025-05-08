import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/utils/date_utils.dart' as custom_date;

class OrderDetailPage extends StatefulWidget {
  final Order? order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _isUpdating = false;
  final _quantityController = TextEditingController();
  List<OrderItem> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _orderItems = widget.order?.orderItems ?? [];
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _updateOrder() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      // Calculate total quantity from order items
      final totalQuantity =
          _orderItems.fold(0, (sum, item) => sum + item.quantity);

      // Log the update operation
      print(
          'Updating order #${widget.order!.id} with ${_orderItems.length} items, total quantity: $totalQuantity');

      // Call API to update order
      await ApiService.updateOrder(
        orderId: widget.order!.id,
        orderItems: _orderItems.map((item) => item.toJson()).toList(),
      );

      Get.snackbar(
        'Success',
        'Order updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      // Return true to indicate an update was made
      Get.back(result: true);
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _updateOrderItemQuantity(OrderItem item, int newQuantity) {
    setState(() {
      final index = _orderItems.indexOf(item);
      if (index != -1) {
        _orderItems[index] = OrderItem(
          id: item.id,
          productId: item.productId,
          quantity: newQuantity,
          product: item.product,
          priceOptionId: item.priceOptionId,
        );
      }
    });
  }

  void _removeOrderItem(OrderItem item) {
    setState(() {
      _orderItems.remove(item);
    });
  }

  void _navigateToUpdateOrder() {
    if (widget.order == null) return;

    Get.to(
      () => AddOrderPage(
        outlet: widget.order!.client,
        order: widget.order,
      ),
      preventDuplicates: true,
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Order not found'),
        ),
      );
    }

    final theme = Theme.of(context);
    // Use the totalAmount from the order model instead of recalculating
    final totalAmount = widget.order!.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order!.id}'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Order Header
                _buildSectionHeader(context, 'Order Summary'),
                _buildOrderInfoCard(context),
                const SizedBox(height: 24),

                // Items List
                _buildSectionHeader(context, 'Items (${_orderItems.length})'),
                if (_orderItems.isEmpty)
                  _buildEmptyState()
                else
                  ..._orderItems.map((item) => _buildOrderItemTile(item)),

                // Total Amount Section
                const SizedBox(height: 24),
                _buildTotalSection(context, totalAmount),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildOrderInfoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildInfoRow('Order Date',
              custom_date.DateUtils.formatDateTime(widget.order!.createdAt)),
          const Divider(height: 16),
          _buildInfoRow('Outlet', widget.order!.client.name),
          const Divider(height: 16),
          _buildInfoRow('Status',
              widget.order!.status.toString().split('.').last.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: item.product?.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    ImageUtils.getGridUrl(item.product!.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
        ),
        title: Text(
          item.product?.name ?? 'Unknown Product',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: () {
                if (item.quantity > 1) {
                  _updateOrderItemQuantity(item, item.quantity - 1);
                }
              },
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: () {
                _updateOrderItemQuantity(item, item.quantity + 1);
              },
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _removeOrderItem(item),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 36,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No items in this order',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, double totalAmount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildTotalRow(context, 'Subtotal', totalAmount),
          const Divider(height: 12),
          _buildTotalRow(context, 'Tax', 0.0),
          const Divider(height: 12),
          _buildTotalRow(
            context,
            'Total',
            totalAmount,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, double amount,
      {bool isTotal = false}) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isPending = widget.order?.status == OrderStatus.PENDING;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPending)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Only pending orders can be updated',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed:
                    isPending && !_isUpdating ? _navigateToUpdateOrder : null,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.edit, size: 16),
                label: Text(
                  _isUpdating ? 'Updating...' : 'Edit Order',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
