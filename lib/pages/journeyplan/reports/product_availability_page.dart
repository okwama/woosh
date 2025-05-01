import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/pages/journeyplan/reports/base_report_page.dart';
import 'package:woosh/services/api_service.dart';
//           productReport: report.productReport,
class ProductAvailabilityPage extends BaseReportPage {
  const ProductAvailabilityPage({
    super.key,
    required super.journeyPlan,
  }) : super(reportType: ReportType.PRODUCT_AVAILABILITY);

  @override
  State<ProductAvailabilityPage> createState() =>
      _ProductAvailabilityPageState();
}

class _ProductAvailabilityPageState extends State<ProductAvailabilityPage>
    with BaseReportPageMixin {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = true;

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

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  void resetForm() {
    setState(() {
      _selectedProduct = null;
      _quantityController.clear();
      commentController.clear();
      isSubmitting = false;
    });
  }

  @override
  Future<void> onSubmit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the quantity')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    final box = GetStorage();
    final userId = box.read('userId');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final report = Report(
      type: ReportType.PRODUCT_AVAILABILITY,
      journeyPlanId: widget.journeyPlan.id!,
      salesRepId: userId,
      clientId: widget.journeyPlan.client.id,
      productReport: ProductReport(
        reportId: 0, // This will be set by the backend
        productName: _selectedProduct!.name,
        quantity: quantity,
        comment: commentController.text,
      ),
    );

    await submitReport(report);
  }

  @override
  Widget buildReportForm() {  
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Availability',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Additional Comments',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
