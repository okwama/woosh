import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
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
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

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

  void _showOrderSuccessDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Order Successful'),
          ],
        ),
        content: const Text('Your order has been placed successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.offNamed('/home'); // Go to home
            },
            child: const Text('Back to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.offNamed('/orders'); // Go to orders page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Orders'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> placeOrder() async {
    try {
      isLoading.value = true;

      // Validate outlet ID
      final outletId = widget.outlet.id;
      if (outletId == null) {
        Get.snackbar(
          'Error',
          'Invalid outlet selected',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Validate cart has items
      if (cartController.items.isEmpty) {
        Get.snackbar(
          'Error',
          'Cart is empty',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Prepare order items
      final List<Map<String, dynamic>> orderItems = [];
      for (var item in cartController.items) {
        if (item.product == null) {
          Get.snackbar(
            'Error',
            'Invalid product in cart',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        if (item.quantity <= 0) {
          Get.snackbar(
            'Error',
            'Invalid quantity for ${item.product?.name ?? "Unknown Product"}',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        orderItems.add({
          'productId': item.productId,
          'quantity': item.quantity,
          'priceOptionId': item.priceOptionId,
        });
      }

      if (widget.order == null) {
        // Create new order
        try {
          final order = await ApiService.createOrder(
            clientId: outletId,
            items: orderItems,
          );

          // Order was successful (either null or valid order object)
          cartController.clear();
          _showOrderSuccessDialog(); // Show success dialog with navigation options
        } catch (e) {
          handleOrderError(e);
        }
      } else {
        // Update existing order
        try {
          await ApiService.updateOrder(
            orderId: widget.order!.id,
            orderItems: orderItems,
          );

          Get.snackbar(
            'Success',
            'Order updated successfully',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          cartController.clear();
          Get.offNamed('/orders');
        } catch (e) {
          handleOrderError(e);
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  void handleOrderError(dynamic error) async {
    String errorMessage = error.toString();
    print('Order error: $errorMessage');

    // If the response was a success but the returned data was incomplete,
    // ApiService.createOrder will now show a success dialog and return null.
    // So, here, we only need to handle actual errors (like stock issues).
    if (errorMessage.contains('Insufficient stock')) {
      final RegExp regex = RegExp(r'Insufficient stock for product (.+)');
      final match = regex.firstMatch(errorMessage);
      final productName = match?.group(1) ?? 'Unknown Product';

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Out of Stock'),
            content: Text(
                '$productName is currently out of stock or has insufficient quantity.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // For any other error, show a generic error message
      Get.snackbar(
        'Order Error',
        'There was a problem placing your order. Please try again or check your orders list.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
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

  Widget _buildCartItem(int index, OrderItem item) {
    final packSize = item.product?.packSize;
    final totalPieces = (packSize != null) ? item.quantity * packSize : null;
    return Card(
      key: ValueKey('cart_item_${index}_${item.productId}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.product?.imageUrl != null
                  ? Image.network(
                      ImageUtils.getGridUrl(item.product!.imageUrl!),
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
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.name ?? 'Unknown Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.priceOptionId != null)
                    Text(
                      'Price Option: ${item.product?.priceOptions.firstWhereOrNull((po) => po.id == item.priceOptionId)?.option ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    'Quantity: ${item.quantity}' +
                        (packSize != null
                            ? ' pack(s) (${totalPieces} pcs)'
                            : ''),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final newQuantity = item.quantity - 1;
                        if (newQuantity > 0) {
                          cartController.updateItemQuantity(item, newQuantity);
                        } else {
                          cartController.removeItem(item);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final newQuantity = item.quantity + 1;
                        if (item.product?.storeQuantities == null ||
                            newQuantity <=
                                item.product!.storeQuantities.first.quantity) {
                          cartController.updateItemQuantity(item, newQuantity);
                        } else {
                          Get.snackbar(
                            'Error',
                            'Cannot exceed available stock',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.red[400],
                            colorText: Colors.white,
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
                if (item.priceOptionId != null)
                  Text(
                    'Ksh ${(item.product?.priceOptions.firstWhereOrNull((po) => po.id == item.priceOptionId)?.value ?? 0) * item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
        final totalItems =
            cartController.items.fold(0, (sum, item) => sum + item.quantity);
        final totalAmount = cartController.totalAmount;
        final totalPieces = cartController.items.fold(
            0,
            (sum, item) =>
                sum +
                ((item.product?.packSize != null)
                    ? item.quantity * item.product!.packSize!
                    : 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$totalItems',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            if (totalPieces > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pieces',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$totalPieces',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Ksh ${totalAmount.toStringAsFixed(2)}',
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
        final loading = isLoading.value;
        final hasItems = cartController.items.isNotEmpty;

        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: !loading
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
                onPressed: (!loading && hasItems) ? placeOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
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
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            if (errorMessage.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            Expanded(
              child: cartController.items.isEmpty
                  ? _buildEmptyCart()
                  : ListView.builder(
                      itemCount: cartController.items.length,
                      itemBuilder: (context, index) {
                        final item = cartController.items[index];
                        return _buildCartItem(index, item);
                      },
                    ),
            ),
            if (cartController.items.isNotEmpty) _buildTotalSection(),
          ],
        );
      }),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
