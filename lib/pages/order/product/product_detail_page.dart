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
    super.key,
    required this.outlet,
    required this.product,
    this.order,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _quantityController = TextEditingController(text: '1');
  final _cartController = Get.find<CartController>();

  @override
  void initState() {
    super.initState();
    _loadExistingQuantity();
  }

  void _loadExistingQuantity() {
    final existingItem = _cartController.items.firstWhereOrNull(
      (item) => item.product.id == widget.product.id,
    );
    if (existingItem != null) {
      _quantityController.text = existingItem.quantity.toString();
    }
  }

  void _adjustQuantity(int delta) {
    final current = int.tryParse(_quantityController.text) ?? 1;
    final newValue = current + delta;
    final maxStock = widget.product.currentStock;

    if (newValue > 0 && (maxStock == null || newValue <= maxStock)) {
      setState(() => _quantityController.text = newValue.toString());
    }
  }

  Future<void> _addToCart() async {
    try {
      final quantity = int.parse(_quantityController.text);
      _cartController.addToCart(widget.product, quantity);

      Get.snackbar(
        'Added to Cart',
        '${widget.product.name} × $quantity',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        borderRadius: 8,
        duration: const Duration(seconds: 1),
      );

      Get.off(
        () => CartPage(outlet: widget.outlet, order: widget.order),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 200),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Couldn\'t add to cart',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
        borderRadius: 8,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = widget.product.currentStock == 0;
    final theme = Theme.of(context);

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

                // Price and Stock
                // _PriceRow(
                //   price: widget.product.price ?? 0,
                //   currentStock: widget.product.currentStock,
                // ),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 24),

                // Quantity Selector
                _QuantitySelector(
                  controller: _quantityController,
                  onDecrement: () => _adjustQuantity(-1),
                  onIncrement: () => _adjustQuantity(1),
                  maxQuantity: widget.product.currentStock,
                ),

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
        child: ElevatedButton(
          onPressed: isOutOfStock ? null : _addToCart,
          style: ElevatedButton.styleFrom(
            backgroundColor: isOutOfStock ? Colors.grey[300] : Colors.black,
            foregroundColor: isOutOfStock ? Colors.grey[600] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            isOutOfStock ? 'Out of Stock' : 'Add to Cart',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
