import 'package:flutter/material.dart';
import 'package:whoosh/models/journeyplan_model.dart';

class Product {
  final String name;
  final int currentStock;
  final int reorderPoint;
  final int orderQuantity;

  Product({
    required this.name,
    required this.currentStock,
    required this.reorderPoint,
    this.orderQuantity = 0,
  });
}

class ReportsOrdersPage extends StatefulWidget {
  final JourneyPlan journeyPlan;

  const ReportsOrdersPage({
    super.key,
    required this.journeyPlan,
  });

  @override
  State<ReportsOrdersPage> createState() => _ReportsOrdersPageState();
}

class _ReportsOrdersPageState extends State<ReportsOrdersPage> {
  final _reportController = TextEditingController();
  bool _isSubmitting = false;
  List<Product> _products = [
    Product(name: 'Product 1', currentStock: 10, reorderPoint: 5),
    Product(name: 'Product 2', currentStock: 15, reorderPoint: 8),
    Product(name: 'Product 3', currentStock: 3, reorderPoint: 10),
  ];

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_reportController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a report')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: Implement report submission
      await Future.delayed(const Duration(seconds: 2)); // Simulated API call

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      // Clear the form
      _reportController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showInventoryDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Inventory'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _products
                .map((product) => _buildInventoryItem(product))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save inventory updates
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(Product product) {
    final currentStockController =
        TextEditingController(text: product.currentStock.toString());
    final orderQuantityController =
        TextEditingController(text: product.orderQuantity.toString());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: currentStockController,
                  decoration: const InputDecoration(
                    labelText: 'Current Stock',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: orderQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Order Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reorder Point: ${product.reorderPoint}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Orders'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                            widget.journeyPlan.outlet.name,
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
                      widget.journeyPlan.outlet.address,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Inventory Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Inventory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showInventoryDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text('Update Inventory'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            'Current Stock: ${product.currentStock} | Reorder Point: ${product.reorderPoint}',
                          ),
                          trailing: product.currentStock <= product.reorderPoint
                              ? const Icon(Icons.warning, color: Colors.red)
                              : const Icon(Icons.check_circle,
                                  color: Colors.green),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Report Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reportController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter your report here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Submit Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Orders Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Orders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Implement new order creation
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New Order'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // TODO: Implement orders list
                    Center(
                      child: Text(
                        'No orders yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
