import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/pages/order/addorder_page.dart';
import 'package:woosh/utils/image_utils.dart';

class OrderDetailPage extends StatelessWidget {
  final Order? order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

  void _navigateToUpdateOrder() {
    if (order == null) return;

    Get.to(
      () => AddOrderPage(
        outlet: order!.outlet,
        order: order,
      ),
      preventDuplicates: true,
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (order == null) {
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
    final totalAmount = order!.orderItems.fold(
      0.0,
      (sum, item) => sum + (item.product?.price ?? 0) * item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order!.id}'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToUpdateOrder,
          ),
        ],
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
                _buildSectionHeader(
                    context, 'Items (${order!.orderItems.length})'),
                if (order!.orderItems.isEmpty)
                  _buildEmptyState()
                else
                  ...order!.orderItems
                      .map((item) => _buildOrderItemTile(item))
                      .toList(),

                // Total Section
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow('Order Date',
              DateFormat('MMM dd, yyyy • h:mm a').format(order!.createdAt)),
          const Divider(height: 24),
          _buildInfoRow('Outlet', order!.outlet.name),
          const Divider(height: 24),
          _buildInfoRow(
              'Status', order!.status.toString().split('.').last.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.product?.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ImageUtils.getGridUrl(item.product!.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.grey,
                ),
        ),
        title: Text(
          item.product?.name ?? 'Unknown Product',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${item.quantity} × Ksh ${(item.product?.price ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Text(
          'Ksh ${(item.quantity * (item.product?.price ?? 0)).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No items in this order',
            style: TextStyle(
              color: Colors.grey.shade500,
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
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTotalRow(context, 'Subtotal', totalAmount),
          const Divider(height: 16),
          _buildTotalRow(context, 'Tax', 0.0),
          const Divider(height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
          Text(
            'Ksh ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _navigateToUpdateOrder,
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Update Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
