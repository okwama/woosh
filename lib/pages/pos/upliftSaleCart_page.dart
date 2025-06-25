import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/models/order_model.dart';
import 'package:glamour_queen/models/product_model.dart';
import 'package:glamour_queen/models/client_stock_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/client_stock_service.dart';
import 'package:glamour_queen/utils/image_utils.dart';

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
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingStock = false;
  List<ClientStock> _clientStocks = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _selectedProductIds = {};
  Map<int, int> _selectedQuantities = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProducts();
    _loadClientStock();
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      final products = await ApiService.getProducts().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      setState(() {
        _products = products;
      });
    } catch (e) {
      setState(() {
        _products = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadClientStock() async {
    try {
      setState(() {
        _isLoadingStock = true;
      });

      final stocks =
          await ClientStockService.getClientStock(widget.outlet.id).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      setState(() {
        _clientStocks = stocks;
      });
    } catch (e) {
      setState(() {
        _clientStocks = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load stock data: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _isLoadingStock = false;
      });
    }
  }

  int _getAvailableStock(int productId) {
    final stock = _clientStocks.firstWhere(
      (s) => s.productId == productId,
      orElse: () => ClientStock(
        id: 0,
        quantity: 0,
        clientId: widget.outlet.id,
        productId: productId,
      ),
    );
    return stock.quantity;
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products
        .where((product) =>
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _toggleProductSelection(int productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        _selectedQuantities.remove(productId);
      } else {
        _selectedProductIds.add(productId);
        _selectedQuantities[productId] = 1;
      }
    });
  }

  void _updateQuantity(int productId, int quantity) {
    final maxStock = _getAvailableStock(productId);
    if (quantity > 0 && quantity <= maxStock) {
      setState(() {
        _selectedQuantities[productId] = quantity;
      });
    }
  }

  void _showOrderConfirmationDialog() {
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to proceed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedProducts =
        _products.where((p) => _selectedProductIds.contains(p.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => OrderConfirmationDialog(
        products: selectedProducts,
        quantities: _selectedQuantities,
        getAvailableStock: _getAvailableStock,
        outlet: widget.outlet,
        onOrderPlaced: () {
          setState(() {
            _selectedProductIds.clear();
            _selectedQuantities.clear();
          });
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uplift sale created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushNamed(context, '/uplift-sales');
          });
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildProductListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 40),
          SizedBox(width: 160),
          SizedBox(width: 50),
          SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildProductListItem(Product product, int index) {
    final stock = _getAvailableStock(product.id);
    final isInStock = stock > 0;
    final isSelected = _selectedProductIds.contains(product.id);
    final quantity = _selectedQuantities[product.id] ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged:
              isInStock ? (value) => _toggleProductSelection(product.id) : null,
          activeColor: Theme.of(context).primaryColor,
        ),
        title: Row(
          children: [
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isInStock ? Colors.black : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.packSize != null)
                    Text(
                      'Pack Size: ${product.packSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInStock ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isInStock ? Colors.green[200]! : Colors.red[200]!,
                  ),
                ),
                child: Text(
                  '$stock',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isInStock ? Colors.green[700] : Colors.red[700],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: isSelected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (quantity > 1) {
                              _updateQuantity(product.id, quantity - 1);
                            }
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: quantity > 1
                                  ? Colors.blue[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: quantity > 1
                                    ? Colors.blue[300]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 12,
                              color: quantity > 1
                                  ? Colors.blue[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          width: 24,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Center(
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () {
                            if (quantity < stock) {
                              _updateQuantity(product.id, quantity + 1);
                            }
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: quantity < stock
                                  ? Colors.blue[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: quantity < stock
                                    ? Colors.blue[300]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 12,
                              color: quantity < stock
                                  ? Colors.blue[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      isInStock
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: isInStock ? Colors.green : Colors.red,
                      size: 20,
                    ),
            ),
          ],
        ),
        onTap: isInStock ? () => _toggleProductSelection(product.id) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_selectedProductIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalItems =
        _selectedQuantities.values.fold(0, (sum, qty) => sum + qty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_selectedProductIds.length} products selected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Total quantity: $totalItems',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showOrderConfirmationDialog,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Place Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Products'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/uplift-sales');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProducts();
              _loadClientStock();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (kDebugMode)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.yellow[100],
                child: Row(
                  children: [
                    Text('Loading: $_isLoadingProducts'),
                    const SizedBox(width: 16),
                    Text('Products: ${_products.length}'),
                    const SizedBox(width: 16),
                    Text('Stock: ${_clientStocks.length}'),
                  ],
                ),
              ),
            _buildSearchBar(),
            _buildProductListHeader(),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading products...'),
                        ],
                      ),
                    )
                  : _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text(
                                'No products available',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please check your connection and try again',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _loadProducts();
                                  _loadClientStock();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No products found',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search: "$_searchQuery"',
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                return _buildProductListItem(
                                    _filteredProducts[index], index);
                              },
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }
}

class OrderConfirmationDialog extends StatefulWidget {
  final List<Product> products;
  final Map<int, int> quantities;
  final int Function(int) getAvailableStock;
  final Outlet outlet;
  final VoidCallback onOrderPlaced;

  const OrderConfirmationDialog({
    super.key,
    required this.products,
    required this.quantities,
    required this.getAvailableStock,
    required this.outlet,
    required this.onOrderPlaced,
  });

  @override
  State<OrderConfirmationDialog> createState() =>
      _OrderConfirmationDialogState();
}

class _OrderConfirmationDialogState extends State<OrderConfirmationDialog> {
  final Map<int, TextEditingController> _priceControllers = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (var product in widget.products) {
      _priceControllers[product.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalAmount {
    double total = 0;
    for (var product in widget.products) {
      final quantity = widget.quantities[product.id] ?? 0;
      final price =
          double.tryParse(_priceControllers[product.id]?.text ?? '') ?? 0;
      total += quantity * price;
    }
    return total;
  }

  Future<void> _placeOrder() async {
    bool hasError = false;

    // Validate all prices are entered and quantities are within stock limits
    for (var product in widget.products) {
      final price = double.tryParse(_priceControllers[product.id]!.text);
      final quantity = widget.quantities[product.id] ?? 0;
      final availableStock = widget.getAvailableStock(product.id);

      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter valid price for ${product.name}'),
            backgroundColor: Colors.red,
          ),
        );
        hasError = true;
        break;
      }

      if (quantity > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Quantity for ${product.name} exceeds available stock (${availableStock})'),
            backgroundColor: Colors.red,
          ),
        );
        hasError = true;
        break;
      }
    }

    if (hasError) return;

    try {
      setState(() {
        _isProcessing = true;
      });

      // Prepare order items in the format expected by the API
      final orderItems = widget.products.map((product) {
        final quantity = widget.quantities[product.id] ?? 0;
        final unitPrice = double.parse(_priceControllers[product.id]!.text);

        return {
          'productId': product.id,
          'quantity': quantity,
          'unitPrice': unitPrice,
        };
      }).toList();

      // Call the API to create the uplift sale
      final result = await ApiService.createUpliftSale(
        clientId: widget.outlet.id,
        items: orderItems,
      );

      if (result != null && result['success'] == true) {
        // Success - show success message and close dialog
        widget.onOrderPlaced();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uplift sale created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Handle API error
        final errorMessage =
            result?['message'] ?? 'Failed to create uplift sale';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle network or other errors
      String errorMessage = 'Failed to create uplift sale';

      if (e.toString().contains('INSUFFICIENT_STOCK')) {
        errorMessage =
            'Insufficient stock for some products. Please check stock levels.';
      } else if (e.toString().contains('Network error')) {
        errorMessage = 'Network error. Please check your connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Confirmation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Order items list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final product = widget.products[index];
                final quantity = widget.quantities[product.id] ?? 0;

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceControllers[product.id],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Unit Price (Ksh)',
                            border: OutlineInputBorder(),
                            prefixText: 'Ksh ',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => setState(() {}), // Update total
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Total and place order
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ksh ${_totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Creating Sale...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle),
                                SizedBox(width: 8),
                                Text(
                                  'Place Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
