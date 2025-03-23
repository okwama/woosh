// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:whoosh/models/order_model.dart';
import 'package:whoosh/models/product_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.order != null) {
      _selectedProduct = widget.order!.product;
      _quantityController.text = widget.order!.quantity.toString();
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

  Future<void> _saveOrder() async {
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
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.order == null) {
        // Create new order
        await ApiService.createOrder(
          outletId: widget.outlet.id,
          productId: _selectedProduct!.id,
          quantity: quantity,
        );
      } else {
        // Update existing order
        await ApiService.updateOrder(
          orderId: widget.order!.id,
          productId: _selectedProduct!.id,
          quantity: quantity,
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Failed to save order: $e';
        _isLoading = false;
      });
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
                  DropdownButtonFormField<Product>(
                    value: _selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                    items: _products.map((product) {
                      return DropdownMenuItem(
                        value: product,
                        child: Text(product.name),
                      );
                    }).toList(),
                    onChanged: (Product? value) {
                      setState(() {
                        _selectedProduct = value;
                      });
                    },
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      widget.order == null ? 'Create Order' : 'Update Order',
                    ),
                  ),
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
