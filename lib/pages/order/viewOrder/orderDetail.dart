import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/hive/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/addorder_page.dart';
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
  Map<String, dynamic>? _voidStatus;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _orderItems = widget.order?.items ?? [];
    _checkVoidStatus();
  }

  Future<void> _checkVoidStatus() async {
    try {
      final status =
          await ApiService.checkVoidStatus(orderId: widget.order!.id);
      if (mounted) {
        setState(() {
          _voidStatus = status;
        });
      }
    } catch (e) {
      // Silently fail - void status is optional
      print('Error checking void status: $e');
    }
  }

  String _getVoidStatusMessage() {
    if (_voidStatus == null) return '';

    final status = _voidStatus!['status'] as int? ?? 0;
    switch (status) {
      case 0:
        return '';
      case 4:
        return 'Void Requested';
      case 5:
        return 'Order Voided';
      case 6:
        return 'Void Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getVoidStatusColor() {
    if (_voidStatus == null) return Colors.transparent;

    final status = _voidStatus!['status'] as int? ?? 0;
    switch (status) {
      case 0:
        return Colors.transparent;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      case 6:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Get status color based on order status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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
      case 'voided':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status icon based on order status
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
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
      case 'voided':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _voidOrder() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Text('Request Order Void', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Are you sure you want to request a void for this order?',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${widget.order!.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                        'Amount: ${currencyFormat.format(widget.order!.totalAmount)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will submit a void request for admin approval.',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Request Void', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _isUpdating = true);

        // Submit void request to API
        final result = await ApiService.requestOrderVoid(
          orderId: widget.order!.id,
          reason: 'Customer requested void',
        );

        if (result['success'] == true) {
          Get.snackbar(
            'Success',
            'Void request submitted successfully. Waiting for admin approval.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          // Refresh void status
          await _checkVoidStatus();

          Get.back(result: true);
        } else {
          throw Exception('Failed to submit void request');
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit void request: $e',
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

  Future<void> _updateOrder() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final totalQuantity =
          _orderItems.fold(0, (sum, item) => sum + item.quantity);

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

  void _navigateToUpdateOrder() async {
    if (widget.order == null) return;

    try {
      final outlets = await ApiService.fetchOutlets();
      final outlet = outlets.firstWhere((o) => o.id == widget.order!.clientId);

      Get.to(
        () => AddOrderPage(
          outlet: outlet,
          order: widget.order,
        ),
        preventDuplicates: true,
        transition: Transition.rightToLeft,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to fetch outlet details: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
    final isPending = order.status.toLowerCase() == 'pending';
    final canVoid = isPending && (_voidStatus?['canRequestVoid'] ?? true);
    final voidStatusMessage = _getVoidStatusMessage();
    final voidStatusColor = _getVoidStatusColor();

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
              custom_date.DateUtils.formatDateTime(widget.order!.orderDate)),
          const Divider(height: 16),
          _buildInfoRow('Outlet', widget.order!.clientId.toString()),
          const Divider(height: 16),
          _buildInfoRow('Status', widget.order!.status),
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

  Widget _buildOrderItemTile(OrderItemModel item) {
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

  Widget _buildBottomBar(BuildContext context) {
    final order = widget.order!;
    final isPending = order.status.toLowerCase() == 'pending';
    final canVoid = isPending && (_voidStatus?['canRequestVoid'] ?? true);
    final voidStatusMessage = _getVoidStatusMessage();
    final voidStatusColor = _getVoidStatusColor();

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
          if (canVoid) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _voidOrder,
                icon: const Icon(Icons.block, size: 16),
                label:
                    const Text('Request Void', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else if (voidStatusMessage.isNotEmpty) ...[
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: voidStatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: voidStatusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      voidStatusColor == Colors.orange
                          ? Icons.schedule
                          : voidStatusColor == Colors.red
                              ? Icons.cancel
                              : Icons.help_outline,
                      size: 14,
                      color: voidStatusColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        voidStatusMessage,
                        style: TextStyle(
                          color: voidStatusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
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
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.edit, size: 16),
              label: Text(_isUpdating ? 'Updating...' : 'Edit Order',
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
        ],
      ),
    );
  }
}
