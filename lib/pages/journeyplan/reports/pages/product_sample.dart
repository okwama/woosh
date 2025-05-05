import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/product_sample_item_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class ProductSamplePage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onReportSubmitted;

  const ProductSamplePage({
    super.key,
    required this.journeyPlan,
    this.onReportSubmitted,
  });

  @override
  State<ProductSamplePage> createState() => _ProductSamplePageState();
}

class _ProductSamplePageState extends State<ProductSamplePage> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  bool _isLoading = true;
  Product? _selectedProduct;
  List<Product> _products = [];

  // Cart: List of maps with product, quantity, reason
  List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ApiService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _addToCart() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }
    if (_quantityController.text.isEmpty ||
        int.tryParse(_quantityController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }
    setState(() {
      _cart.add({
        'product': _selectedProduct!,
        'quantity': int.parse(_quantityController.text),
        'reason': _reasonController.text.trim(),
      });
      _selectedProduct = null;
      _quantityController.clear();
      _reasonController.clear();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

Future<void> _submitCart() async {
  if (_cart.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cart is empty')),
    );
    return;
  }
  setState(() => _isSubmitting = true);
  try {
    final box = GetStorage();
    final salesRepData = box.read('salesRep');
    final int? salesRepId =
        salesRepData is Map<String, dynamic> ? salesRepData['id'] : null;
    if (salesRepId == null) {
      throw Exception("User not authenticated: Could not determine salesRep ID");
    }

    // Build the list of ProductSampleItem
    final items = _cart.map((item) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      final reason = item['reason'] as String;
      return ProductSampleItem(
        productName: product.name,
        quantity: quantity,
        reason: reason,
      );
    }).toList();

    // Submit a single report with all items
    final report = Report(
      type: ReportType.PRODUCT_SAMPLE,
      journeyPlanId: widget.journeyPlan.id,
      salesRepId: salesRepId,
      clientId: widget.journeyPlan.client.id,
      productSampleItems: items,
    );
    await _apiService.submitReport(report);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product sample report submitted successfully')),
      );
      widget.onReportSubmitted?.call();
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Product Sample Report',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outlet Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.journeyPlan.client.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.journeyPlan.client.address,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Sample Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_products.isEmpty)
                      const Center(
                        child: Text(
                          'No products available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
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
                        onChanged: (value) {
                          setState(() => _selectedProduct = value);
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Add to Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cart List
            if (_cart.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          final product = item['product'] as Product;
                          final quantity = item['quantity'] as int;
                          final reason = item['reason'] as String;
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text('Qty: $quantity\nReason: $reason'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeFromCart(index),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit All'),
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

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
