import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/hive/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/utils/date_utils.dart' as custom_date;
import 'package:woosh/utils/country_currency_labels.dart';
import 'package:get_storage/get_storage.dart';

class OrderDetailPage extends StatefulWidget {
  final OrderModel? order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _isUpdating = false;
  List<OrderItemModel> _orderItems = [];

  final currencyFormat = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _orderItems = widget.order?.items ?? [];
  }

  // Get status color based on order status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status icon based on order status
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.edit;
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.refresh;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // Check if order can be edited (draft or pending status)
  bool _canEditOrder() {
    final status = widget.order?.status.toLowerCase() ?? '';
    return status == 'draft' || status == 'pending';
  }

  Future<void> _updateOrder() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final totalQuantity =
          _orderItems.fold(0, (sum, item) => sum + item.quantity);

      // Convert OrderItemModel to the format expected by the API
      final orderItemsForApi = _orderItems
          .map((item) => {
                'productId': item.productId,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
              })
          .toList();

      await ApiService.updateOrder(
        orderId: widget.order!.id,
        orderItems: orderItemsForApi,
      );

      Get.snackbar(
        'Success',
        'Order updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
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

  void _updateOrderItemQuantity(OrderItemModel item, int newQuantity) {
    setState(() {
      final index = _orderItems.indexOf(item);
      if (index != -1) {
        _orderItems[index] = OrderItemModel(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: newQuantity,
          unitPrice: item.unitPrice,
        );
      }
    });
  }

  void _removeOrderItem(OrderItemModel item) {
    setState(() {
      _orderItems.remove(item);
    });
  }

  double get totalAmount {
    return _orderItems.fold(
        0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
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

    final order = widget.order!;
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final canEdit = _canEditOrder();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Order #${order.id}', style: const TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  ..._orderItems
                      .map((item) => _buildOrderItemTile(item, canEdit)),

                // Total Amount Section
                const SizedBox(height: 24),
                _buildTotalSection(context, totalAmount),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, canEdit),
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
    final order = widget.order!;
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);

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
              custom_date.DateUtils.formatDateTime(order.orderDate)),
          const Divider(height: 16),
          _buildInfoRow('Outlet', order.clientId.toString()),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildOrderItemTile(OrderItemModel item, bool canEdit) {
    // Add debugging to see what data we have
    print('[OrderItem Debug] Item: ${item.productName}');
    print(
        '[OrderItem Debug] Unit Price: ${item.unitPrice} (${item.unitPrice.runtimeType})');
    print('[OrderItem Debug] Quantity: ${item.quantity}');
    print('[OrderItem Debug] Raw item data: ${item.toJson()}');

    final itemTotal = (item.unitPrice ?? 0.0) * item.quantity;

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
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      if (item.quantity > 1) {
                        _updateOrderItemQuantity(item, item.quantity - 1);
                      }
                    },
                  ),
                ],
                Text(
                  '${item.quantity}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      _updateOrderItemQuantity(item, item.quantity + 1);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unit Price: ${item.unitPrice != null ? CountryCurrencyLabels.formatCurrency(item.unitPrice, null) : 'N/A'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Total: ${itemTotal > 0 ? CountryCurrencyLabels.formatCurrency(itemTotal, null) : 'N/A'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: canEdit
            ? IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _removeOrderItem(item),
              )
            : null,
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
    // Get user's country ID for currency formatting
    final box = GetStorage();
    final salesRep = box.read('salesRep');
    final userCountryId = salesRep?['countryId'];

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
            CountryCurrencyLabels.formatCurrency(amount, userCountryId),
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

  Widget _buildBottomBar(BuildContext context, bool canEdit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (canEdit) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _updateOrder,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Icon(Icons.save, size: 16),
                label: Text(_isUpdating ? 'Updating...' : 'Update Order',
                    style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Order cannot be edited',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
