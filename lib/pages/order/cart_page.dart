import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/product/products_grid_page.dart';
import 'package:woosh/utils/image_utils.dart';

class CartPage extends StatefulWidget {
  final Outlet outlet;
  final Order? order;

  const CartPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with WidgetsBindingObserver {
  final CartController cartController = Get.find<CartController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    ImageCache().clear();
    ImageCache().clearLiveImages();
  }

  Future<void> placeOrder() async {
    try {
      cartController.isLoading.value = true;

      // Validate outlet ID (backend requirement)
      final outletId = widget.outlet.id;
      if (outletId == null) {
        throw Exception('Invalid outlet ID');
      }

      // Validate cart has items (backend requirement)
      if (cartController.items.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Prepare order items in the format expected by the backend
      final orderItems = cartController.items.map((item) {
        // Validate product ID (backend requirement)
        final productId = item.product.id;
        if (productId == null) {
          throw Exception('Invalid product ID for ${item.product.name}');
        }

        final quantity = item.quantity.value;
        // Validate quantity (backend requirement)
        if (quantity <= 0) {
          throw Exception('Invalid quantity for ${item.product.name}');
        }

        return {
          'productId': productId,
          'quantity': quantity,
        };
      }).toList();

      if (widget.order == null) {
        // Create new order with exact backend expected format
        await ApiService.createOrder(
          outletId: outletId,
          items: orderItems,
        );
      } else {
        // Validate order ID before update
        final orderId = widget.order?.id;
        if (orderId == null) {
          throw Exception('Invalid order ID for update');
        }

        // Update existing order
        await ApiService.updateOrder(
          orderId: orderId,
          orderItems: orderItems,
        );
      }

      Get.snackbar(
        'Success',
        widget.order == null
            ? 'Order placed successfully'
            : 'Order updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      cartController.items.clear();
      Get.offNamed('/orders');
    } catch (e) {
      cartController.error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to ${widget.order == null ? 'place' : 'update'} order: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      cartController.isLoading.value = false;
    }
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.off(() => ProductsGridPage(
                  outlet: widget.outlet,
                  order: widget.order,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index, CartItem item) {
    return Card(
      key: ValueKey('cart_item_${item.product.id ?? 'unknown'}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                ImageUtils.getThumbnailUrl(item.product.imageUrl ?? ''),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                        '\Ksh${(item.product.price ?? 0).toStringAsFixed(2)} × ${item.quantity.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      )),
                  Obx(() => Text(
                        'Total: \Ksh${((item.product.price ?? 0) * item.quantity.value).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => cartController.removeFromCart(index),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => cartController.updateQuantity(
                        index,
                        item.quantity.value - 1,
                      ),
                    ),
                    Obx(() => Text(
                          '${item.quantity.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => cartController.updateQuantity(
                        index,
                        item.quantity.value + 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Obx(() {
        double subtotal = cartController.items.fold(
          0,
          (sum, item) => sum + item.total,
        );
        double tax = subtotal * 0.1; // 10% tax
        double total = subtotal + tax;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('\Ksh${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax (10%)'),
                Text('\Ksh${tax.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '\Ksh${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() {
        bool isLoading = cartController.isLoading.value;
        bool hasItems = cartController.items.isNotEmpty;

        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: !isLoading
                    ? () => Get.off(() => ProductsGridPage(
                          outlet: widget.outlet,
                          order: widget.order,
                        ))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add More'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: (!isLoading && hasItems) ? placeOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.order == null ? 'Place Order' : 'Update Order',
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Cart' : 'Edit Order'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: GetX<CartController>(
        builder: (controller) {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (controller.error.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    controller.error.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              Expanded(
                child: controller.items.isEmpty
                    ? _buildEmptyCart()
                    : ListView.builder(
                        itemCount: controller.items.length,
                        itemBuilder: (context, index) {
                          final item = controller.items[index];
                          return _buildCartItem(index, item);
                        },
                      ),
              ),
              if (controller.items.isNotEmpty) _buildTotalSection(),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
