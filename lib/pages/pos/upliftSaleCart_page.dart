import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/controllers/uplift_cart_controller.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/product/products_grid_page.dart';
import 'package:woosh/utils/image_utils.dart';

class UpliftSaleCartPage extends StatefulWidget {
  final Outlet outlet;
  final Order? order;

  const UpliftSaleCartPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  State<UpliftSaleCartPage> createState() => _UpliftSaleCartPageState();
}

class _UpliftSaleCartPageState extends State<UpliftSaleCartPage>
    with WidgetsBindingObserver {
  final UpliftCartController _cartController = Get.find<UpliftCartController>();
  final RxList<Product> _products = <Product>[].obs;
  final RxBool _isLoadingProducts = false.obs;
  Product? _selectedProduct;
  int _quantity = 1;
  int? _selectedPriceOptionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProducts();
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

  Future<void> _loadProducts() async {
    try {
      _isLoadingProducts.value = true;
      final products = await ApiService.getProducts();
      _products.value = products;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load products: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoadingProducts.value = false;
    }
  }

  void _addToCart() {
    if (_selectedProduct == null) {
      Get.snackbar(
        'Error',
        'Please select a product',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_quantity <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid quantity',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    _cartController.addItem(
      _selectedProduct!,
      _quantity,
      priceOptionId: _selectedPriceOptionId,
    );

    // Reset selection
    setState(() {
      _selectedProduct = null;
      _quantity = 1;
      _selectedPriceOptionId = null;
    });

    Get.snackbar(
      'Success',
      'Item added to cart',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
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
      _cartController.isLoading.value = true;

      if (_cartController.isEmpty) {
        Get.snackbar(
          'Error',
          'Cart is empty',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final List<Map<String, dynamic>> orderItems = [];
      for (var item in _cartController.items) {
        orderItems.add({
          'productId': item.product.id,
          'quantity': item.quantity,
          'priceOptionId': item.priceOptionId,
          'unitPrice': item.unitPrice,
        });
      }

      final response = await ApiService.createUpliftSale(
        clientId: widget.outlet.id,
        items: orderItems,
      );

      if (response != null) {
        _cartController.clear();
        _showOrderSuccessDialog();
      }
    } catch (e) {
      _cartController.errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to place order: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _cartController.isLoading.value = false;
    }
  }

  Widget _buildProductSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (_isLoadingProducts.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  border: OutlineInputBorder(),
                ),
                items: _products.map((product) {
                  return DropdownMenuItem<Product>(
                    value: product,
                    child: Text(product.name),
                  );
                }).toList(),
                onChanged: (Product? product) {
                  setState(() {
                    _selectedProduct = product;
                    _selectedPriceOptionId = null;
                  });
                },
              );
            }),
            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              if (_selectedProduct!.priceOptions.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: _selectedPriceOptionId,
                  decoration: const InputDecoration(
                    labelText: 'Select Price Option',
                    border: OutlineInputBorder(),
                  ),
                  items: _selectedProduct!.priceOptions.map((option) {
                    return DropdownMenuItem<int>(
                      value: option.id,
                      child: Text('${option.option} - Ksh ${option.value}'),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      _selectedPriceOptionId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Quantity:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _quantity.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _quantity = int.tryParse(value) ?? 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Add to Cart'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, UpliftCartItem item) {
    final packSize = item.product.packSize;
    final totalPieces = (packSize != null) ? item.quantity * packSize : null;
    return Card(
      key: ValueKey('cart_item_${index}_${item.product.id}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.product.imageUrl != null
                  ? Image.network(
                      ImageUtils.getGridUrl(item.product.imageUrl!),
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
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.priceOptionId != null)
                    Text(
                      'Price Option: ${item.product.priceOptions.firstWhereOrNull((po) => po.id == item.priceOptionId)?.option ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    'Quantity: ${item.quantity}${packSize != null
                            ? ' pack(s) ($totalPieces pcs)'
                            : ''}',
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
                          _cartController.updateItemQuantity(item, newQuantity);
                        } else {
                          _cartController.removeItem(item);
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
                        if (newQuantity <=
                                item.product.storeQuantities.first.quantity) {
                          _cartController.updateItemQuantity(item, newQuantity);
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
                Text(
                  'Ksh ${item.total.toStringAsFixed(2)}',
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
        final totalItems = _cartController.totalItems;
        final totalAmount = _cartController.totalAmount;
        final totalPieces = _cartController.totalPieces;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildProductSelector(),
          Expanded(
            child: Obx(() {
              if (_cartController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  if (_cartController.errorMessage.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _cartController.errorMessage.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _cartController.isEmpty
                        ? const Center(
                            child: Text(
                              'Your cart is empty',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _cartController.items.length,
                            itemBuilder: (context, index) {
                              final item = _cartController.items[index];
                              return _buildCartItem(index, item);
                            },
                          ),
                  ),
                  if (_cartController.isNotEmpty) _buildTotalSection(),
                ],
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: Obx(() {
        final loading = _cartController.isLoading.value;
        final hasItems = _cartController.isNotEmpty;

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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Place Order'),
          ),
        );
      }),
    );
  }
}
