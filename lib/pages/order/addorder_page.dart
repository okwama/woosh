// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:whoosh/models/order_model.dart';
import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:whoosh/models/orderitem_model.dart'; // Add this import
import 'package:get/get.dart'; // Add this import

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  // double get total => product.price * quantity;  // Commented out for future use
}

class AddOrderPage extends StatefulWidget {
  final Outlet outlet;
  final Order? order;

  const AddOrderPage({
    Key? key,
    required this.outlet,
    this.order,
  }) : super(key: key);

  @override
  _AddOrderPageState createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  bool _isLoading = false;
  String? _error;
  List<Product> _products = [];
  Product? _selectedProduct;
  final TextEditingController _quantityController = TextEditingController();
  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.order != null) {
      // Populate the cart items from the order's orderItems
      if (widget.order!.orderItems.isNotEmpty) {
        for (var orderItem in widget.order!.orderItems) {
          if (orderItem.product != null) {
            // Add null check for product
            _cartItems.add(CartItem(
              product: orderItem.product!,
              quantity: orderItem.quantity,
            ));
          }
        }
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await ApiService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  void _addToCart() {
    if (_selectedProduct == null) {
      setState(() => _error = 'Please select a product');
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Please enter a valid quantity');
      return;
    }

    setState(() {
      final existingItem = _cartItems.firstWhere(
        (item) => item.product.id == _selectedProduct!.id,
        orElse: () => CartItem(product: _selectedProduct!, quantity: 0),
      );

      if (existingItem.quantity == 0) {
        _cartItems.add(CartItem(
          product: _selectedProduct!,
          quantity: quantity,
        ));
      } else {
        existingItem.quantity += quantity;
      }

      _selectedProduct = null;
      _quantityController.clear();
      _error = null;
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  // double get _cartTotal {
  //   return _cartItems.fold(0, (sum, item) => sum + item.total);
  // }

  Future<void> _saveOrder() async {
    if (_cartItems.isEmpty) {
      setState(() => _error = 'Please add at least one product to the cart');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = _cartItems
          .map((item) => {
                'productId': item.product.id,
                'quantity': item.quantity,
              })
          .toList();

      if (widget.order == null) {
        // Create new order
        await ApiService.createOrder(
          outletId: widget.outlet.id,
          items: items,
        );
        Get.snackbar(
          'Success',
          'Order created successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        Navigator.pop(context, true);
      } else {
        // Update existing order
        await ApiService.updateOrder(
          orderId: widget.order!.id,
          orderItems: items,
        );
        Get.snackbar(
          'Success',
          'Order updated successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      String errorMessage = 'Failed to save order';

      if (e.toString().contains('Invalid product')) {
        errorMessage = 'One or more products are invalid';
      } else if (e.toString().contains('Insufficient stock')) {
        errorMessage = 'One or more products have insufficient stock';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Create Order' : 'Edit Order'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Add Product to Cart',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<Product>(
                            value: _selectedProduct,
                            decoration: const InputDecoration(
                              labelText: 'Select Product',
                              border: OutlineInputBorder(),
                            ),
                            items: _products.map((product) {
                              return DropdownMenuItem(
                                value: product,
                                key: ValueKey(product.id),
                                child: Text(product.name),
                              );
                            }).toList(),
                            onChanged: (Product? value) {
                              setState(() {
                                _selectedProduct = value;
                                if (value == null) {
                                  _quantityController.clear();
                                }
                              });
                            },
                            isExpanded: true,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_cartItems.isNotEmpty) ...[
                    const Text(
                      'Cart Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return Card(
                          child: ListTile(
                            title: Text(item.product.name),
                            subtitle: Text('Quantity: ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Text(
                                //   '\$${item.total.toStringAsFixed(2)}',
                                //   style: const TextStyle(
                                //     fontWeight: FontWeight.bold,
                                //   ),
                                // ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeFromCart(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Card(
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [
                    //         const Text(
                    //           'Total:',
                    //           style: TextStyle(
                    //             fontSize: 18,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //         Text(
                    //           '\$${_cartTotal.toStringAsFixed(2)}',
                    //           style: const TextStyle(
                    //             fontSize: 18,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.order == null ? 'Place Order' : 'Update Order',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
