import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/pages/order/cart_page.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class ProductDetailPage extends StatefulWidget {
  final Outlet outlet;
  final Product product;
  final Order? order;

  const ProductDetailPage({
    super.key,
    required this.outlet,
    required this.product,
    this.order,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final CartController _cartController = Get.find<CartController>();
  PriceOption? _selectedPriceOption;

  @override
  void initState() {
    super.initState();
    print('Product price options: ${widget.product.priceOptions}');
    if (widget.product.priceOptions.isNotEmpty) {
      _selectedPriceOption = widget.product.priceOptions.first;
      print('Selected price option: $_selectedPriceOption');
    }
  }

  void _adjustQuantity(int delta) {
    final currentValue = int.tryParse(_quantityController.text) ?? 0;
    final newValue = currentValue + delta;
    final maxStock = widget.product.currentStock ?? 0;

    if (newValue > 0 && newValue <= maxStock) {
      _quantityController.text = newValue.toString();
    }
  }

  void _addToCart() {
    print('Available price options: ${widget.product.priceOptions}');
    print('Selected price option: $_selectedPriceOption');

    if (_selectedPriceOption == null) {
      Get.snackbar(
        'Error',
        'Please select a price option',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid quantity',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check stock availability
    if (widget.product.currentStock != null &&
        quantity > widget.product.currentStock!) {
      Get.snackbar(
        'Error',
        'Not enough stock available',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    _cartController.addItem(
      OrderItem(
        productId: widget.product.id,
        quantity: quantity,
        product: widget.product,
        priceOptionId: _selectedPriceOption?.id,
      ),
    );

    // Show success message
    Get.snackbar(
      'Success',
      'Item added to cart',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    // Navigate to cart page
    Get.to(
      () => CartPage(
        outlet: widget.outlet,
        order: widget.order,
      ),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = widget.product.currentStock != null &&
        widget.product.currentStock! <= 0;
    final theme = Theme.of(context);

    print('Building UI with price options: ${widget.product.priceOptions}');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Get.back(),
            ),
            actions: [
              _CartIconButton(
                cartController: _cartController,
                outlet: widget.outlet,
                order: widget.order,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProductHeroImage(product: widget.product),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Product Name
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 12),

                // Stock Status
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? const Color(0xFFFDEDED)
                        : const Color(0xFFEDF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOutOfStock
                        ? 'Out of stock'
                        : '${widget.product.currentStock} in stock',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isOutOfStock
                          ? const Color(0xFFD93025)
                          : const Color(0xFF1E8E3E),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quantity Selector
                if (!isOutOfStock)
                  _QuantitySelector(
                    controller: _quantityController,
                    onDecrement: () => _adjustQuantity(-1),
                    onIncrement: () => _adjustQuantity(1),
                    maxQuantity: widget.product.currentStock,
                  ),

                const SizedBox(height: 24),

                // Price Options
                if (widget.product.priceOptions.isNotEmpty) ...[
                  const Text(
                    'Select Price Option',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PriceOption>(
                        value: _selectedPriceOption,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: widget.product.priceOptions.map((option) {
                          return DropdownMenuItem<PriceOption>(
                            value: option,
                            child: Text(
                              '${option.option} - Ksh ${option.value}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (PriceOption? value) {
                          setState(() {
                            _selectedPriceOption = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 24),

                if (widget.product.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 100), // Space for bottom button
              ]),
            ),
          ),
        ],
      ),

      // Add to Cart Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedPriceOption != null)
                Text(
                  'Selected Price: Ksh ${_selectedPriceOption!.value}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: isOutOfStock ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 0),
                ),
                child: Text(
                  isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Custom Widgets ---

class _ProductHeroImage extends StatelessWidget {
  final Product product;
  const _ProductHeroImage({required this.product});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'product-image-${product.id}',
      child: Container(
        color: const Color(0xFFF8F8F8),
        child: product.imageUrl != null
            ? Image.network(
                ImageUtils.getDetailUrl(product.imageUrl!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _PlaceholderImage(),
              )
            : const _PlaceholderImage(),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 80,
        color: Color(0xFFDDDDDD),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final double price;
  final int? currentStock;
  const _PriceRow({required this.price, this.currentStock});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ksh ${price.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        if (currentStock != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: currentStock! > 0
                  ? const Color(0xFFEDF7ED)
                  : const Color(0xFFFDEDED),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentStock! > 0 ? '${currentStock} in stock' : 'Out of stock',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: currentStock! > 0
                    ? const Color(0xFF1E8E3E)
                    : const Color(0xFFD93025),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final int? maxQuantity;

  const _QuantitySelector({
    required this.controller,
    required this.onDecrement,
    required this.onIncrement,
    this.maxQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Quantity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: onDecrement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
              SizedBox(
                width: 40,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () {
                  if (maxQuantity == null ||
                      int.parse(controller.text) < maxQuantity!) {
                    onIncrement();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartIconButton extends StatelessWidget {
  final CartController cartController;
  final Outlet outlet;
  final Order? order;

  const _CartIconButton({
    required this.cartController,
    required this.outlet,
    this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final itemCount = cartController.items.length;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon:
                const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
            onPressed: () => Get.to(
              () => CartPage(outlet: outlet, order: order),
              transition: Transition.fadeIn,
            ),
          ),
          if (itemCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  itemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    });
  }
}
