import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/hive/order_model.dart';
import 'package:woosh/models/price_option_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/pages/order/cart_page.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/utils/country_currency_labels.dart';

class ProductDetailPage extends StatefulWidget {
  final Outlet outlet;
  final Product product;
  final OrderModel? order;

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
  int? _regionId;
  final _storage = GetStorage();

  // Performance optimizations
  int? _cachedAvailableStock;
  bool _isInitialized = false;
  bool _isStockLoading = true; // Add loading state for stock

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    // Pre-calculate available stock to avoid repeated calculations
    final userData = _storage.read('salesRep');
    if (userData != null) {
      _regionId = userData['region_id'];
      if (_regionId != null) {
        // Calculate stock asynchronously to avoid blocking UI
        _calculateStockAvailability();
      } else {
        setState(() {
          _isStockLoading = false;
        });
      }
    } else {
      setState(() {
        _isStockLoading = false;
      });
    }

    // Set default price option
    if (widget.product.priceOptions.isNotEmpty) {
      _selectedPriceOption = widget.product.priceOptions.first;
    }

    setState(() {
      _isInitialized = true;
    });
  }

  void _calculateStockAvailability() async {
    // Calculate stock in a separate microtask to avoid blocking UI
    final stock = widget.product.getMaxQuantityInRegion(_regionId!);

    if (mounted) {
      setState(() {
        _cachedAvailableStock = stock;
        _isStockLoading = false;
      });
    }
  }

  void _adjustQuantity(int delta) {
    if (_regionId == null) {
      Get.snackbar(
        'Error',
        'Cannot adjust quantity: No region assigned to your account',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentValue = int.tryParse(_quantityController.text) ?? 0;
    final newValue = currentValue + delta;
    final maxStock = _cachedAvailableStock ?? 0;

    if (newValue > 0 && newValue <= maxStock) {
      _quantityController.text = newValue.toString();
    }
  }

  void _addToCart() {
    if (_regionId == null) {
      Get.snackbar(
        'Error',
        'Cannot add to cart: No region assigned to your account',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

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

    final quantityText = _quantityController.text;
    final quantity = int.tryParse(quantityText) ?? 0;
    final packSize = widget.product.packSize;

    // Prevent partial packs
    if (packSize != null) {
      if (quantity <= 0 ||
          quantityText.contains('.') ||
          int.tryParse(quantityText) == null) {
        Get.snackbar(
          'Error',
          'Please enter a valid whole number of packs (no decimals, no zero, no negative).',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    } else {
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
    }

    // Check stock availability using cached value
    final availableStock = _cachedAvailableStock ?? 0;
    if (quantity > availableStock) {
      Get.snackbar(
        'Error',
        'Not enough stock available in your region',
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
    String successMsg = 'Item added to cart';
    if (widget.product.packSize != null) {
      final totalPieces = quantity * (widget.product.packSize ?? 1);
      successMsg = 'Added $quantity pack(s) ($totalPieces pieces) to cart';
    }
    Get.snackbar(
      'Success',
      successMsg,
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

  Widget _buildStockStatus() {
    if (_isStockLoading) {
      // Show loading state for stock
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.grey[600]!,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking stock...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final availableStock = _cachedAvailableStock ?? 0;
    final isOutOfStock = availableStock <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOutOfStock ? const Color(0xFFFDEDED) : const Color(0xFFEDF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _regionId == null
            ? 'No region assigned to your account'
            : isOutOfStock
                ? 'Out of stock'
                : 'In stock',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _regionId == null
              ? const Color(0xFFD93025)
              : isOutOfStock
                  ? const Color(0xFFD93025)
                  : const Color(0xFF1E8E3E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Get.back(),
          ),
          title: Text(
            widget.product.name,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final availableStock = _cachedAvailableStock ?? 0;
    final isOutOfStock = availableStock <= 0;

    // Get user's country ID for currency formatting
    final userData = _storage.read('salesRep');
    final userCountryId = userData?['countryId'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.product.name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _CartIconButton(
            cartController: _cartController,
            outlet: widget.outlet,
            order: widget.order,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
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
                  widget.product.name +
                      (widget.product.packSize != null
                          ? ' (Sold in packs of ${widget.product.packSize})'
                          : ''),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 12),

                // Stock Status with loading state
                _buildStockStatus(),

                const SizedBox(height: 24),

                // Quantity Selector - only show when stock is loaded and available
                if (!_isStockLoading && !isOutOfStock && availableStock > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuantitySelector(
                        controller: _quantityController,
                        onDecrement: () => _adjustQuantity(-1),
                        onIncrement: () => _adjustQuantity(1),
                        maxQuantity: availableStock,
                      ),
                      if (widget.product.packSize != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'You are ordering in packs. 1 pack = ${widget.product.packSize} pieces.',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ),
                    ],
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
                              '${option.option} - ${CountryCurrencyLabels.formatCurrency(option.value?.toDouble(), userCountryId)}',
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
                  'Selected Price: ${CountryCurrencyLabels.formatCurrency(_selectedPriceOption!.value?.toDouble(), userCountryId)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    (_isStockLoading || isOutOfStock) ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 0),
                ),
                child: Text(
                  _isStockLoading
                      ? 'Checking Stock...'
                      : isOutOfStock
                          ? 'Out of Stock'
                          : 'Add to Cart',
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
              currentStock! > 0 ? '$currentStock in stock' : 'Out of stock',
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
  final OrderModel? order;

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
