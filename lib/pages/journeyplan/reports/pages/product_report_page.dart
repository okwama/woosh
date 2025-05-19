import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/product_model.dart';
import 'package:woosh/models/report/report_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class ProductReportPage extends StatefulWidget {
  final JourneyPlan journeyPlan;
  final VoidCallback? onReportSubmitted;

  const ProductReportPage({
    super.key,
    required this.journeyPlan,
    this.onReportSubmitted,
  });

  @override
  State<ProductReportPage> createState() => _ProductReportPageState();
}

class _ProductReportPageState extends State<ProductReportPage> {
  final _commentController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Product> _products = [];
  Map<int, int> _productQuantities = {}; // Map of productId to quantity
  Map<int, TextEditingController> _quantityControllers =
      {}; // Controllers for quantity fields
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMoreProducts = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    // Dispose all quantity controllers
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreProducts) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ApiService.getProducts(page: 1, limit: _pageSize);
      setState(() {
        _products = products;
        _productQuantities = {for (var product in products) product.id: 0};
        _quantityControllers = {
          for (var product in products)
            product.id: TextEditingController(text: '0')
        };
        _isLoading = false;
        _hasMoreProducts = products.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final moreProducts =
          await ApiService.getProducts(page: nextPage, limit: _pageSize);

      if (mounted) {
        setState(() {
          _products.addAll(moreProducts);
          _productQuantities
              .addAll({for (var product in moreProducts) product.id: 0});
          _quantityControllers.addAll({
            for (var product in moreProducts)
              product.id: TextEditingController(text: '0')
          });
          _currentPage = nextPage;
          _hasMoreProducts = moreProducts.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more products: $e')),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    // Check if at least one product has a quantity > 0
    bool hasQuantities = _productQuantities.values.any((qty) => qty > 0);
    if (!hasQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter quantities for at least one product')),
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
        throw Exception(
            "User not authenticated: Could not determine salesRep ID");
      }

      // Create a list of product reports for products with quantities > 0
      final productReports = _products
          .where((product) => _productQuantities[product.id]! > 0)
          .map((product) => ProductReport(
                reportId: 0,
                productName: product.name,
                productId: product.id,
                quantity: _productQuantities[product.id]!,
                comment: _commentController.text,
              ))
          .toList();

      // Create the report with the product reports
      final report = Report(
        type: ReportType.PRODUCT_AVAILABILITY,
        journeyPlanId: widget.journeyPlan.id,
        salesRepId: salesRepId,
        clientId: widget.journeyPlan.client.id,
        productReports: productReports,
      );

      await _apiService.submitReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
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
        title: 'Product Availability Report',
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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

            // Product Report Form
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
                    else ...[
                      // Products Table
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Product',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  _products.length + (_hasMoreProducts ? 1 : 0),
                              separatorBuilder: (context, index) => Divider(
                                  height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                if (index == _products.length) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }

                                final product = _products[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: TextField(
                                            controller: _quantityControllers[
                                                product.id],
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setState(() {
                                                _productQuantities[product.id] =
                                                    int.tryParse(value) ?? 0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comment',
                          border: OutlineInputBorder(),
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
