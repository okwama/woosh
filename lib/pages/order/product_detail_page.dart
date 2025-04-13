import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/pages/order/cart_page.dart';
import 'package:woosh/utils/image_utils.dart';

class ProductDetailPage extends StatefulWidget {
  final Outlet outlet;
  final Product product;
  final Order? order;

  const ProductDetailPage({
    Key? key,
    required this.outlet,
    required this.product,
    this.order,
  }) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final CartController cartController = Get.find<CartController>();

  @override
  void initState() {
    super.initState();
    // Initialize with existing cart quantity if product is already in cart
    final existingIndex = cartController.items.indexWhere(
      (item) => item.product.id == widget.product.id,
    );
    if (existingIndex >= 0) {
      _quantityController.text =
          cartController.items[existingIndex].quantity.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter quantity';
    }
    final quantity = int.tryParse(value);
    if (quantity == null || quantity <= 0) {
      return 'Please enter a valid quantity';
    }
    if (widget.product.currentStock != null &&
        quantity > widget.product.currentStock!) {
      return 'Quantity exceeds available stock';
    }
    return null;
  }

  void _updateQuantity(int change) {
    final currentValue = int.tryParse(_quantityController.text) ?? 1;
    final newValue = currentValue + change;
    if (newValue > 0 &&
        (widget.product.currentStock == null ||
            newValue <= widget.product.currentStock!)) {
      setState(() {
        _quantityController.text = newValue.toString();
      });
    }
  }

  Future<void> _addToCart() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final quantity = int.parse(_quantityController.text);

      // Add to cart first
      cartController.addToCart(widget.product, quantity);

      // Show success message
      Get.snackbar(
        'Success',
        'Added to cart',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Navigate to cart page
      Get.off(
        () => CartPage(
          outlet: widget.outlet,
          order: widget.order,
        ),
        preventDuplicates: true,
        transition: Transition.rightToLeft,
      );
    } catch (e) {
      // Show error message
      Get.snackbar(
        'Error',
        'Failed to add to cart: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Widget _buildProductImage() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: widget.product.imageUrl != null
          ? Image.network(
              ImageUtils.getDetailUrl(widget.product.imageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                );
              },
            )
          : const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 64,
                color: Colors.grey,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Add cart icon with counter
          Obx(() {
            final itemCount = cartController.items.length;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => Get.to(
                    () => CartPage(outlet: widget.outlet, order: widget.order),
                    preventDuplicates: true,
                  ),
                ),
                if (itemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProductImage(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description?.isNotEmpty == true
                          ? widget.product.description!
                          : 'No description available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.product.currentStock != null) ...[
                      Text(
                        'Available Stock: ${widget.product.currentStock}',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.product.currentStock! > 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${(widget.product.price ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _updateQuantity(-1),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                iconSize: 20,
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _quantityController.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _updateQuantity(1),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
