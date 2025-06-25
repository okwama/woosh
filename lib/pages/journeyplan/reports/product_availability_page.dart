import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/models/journeyplan_model.dart';
import 'package:glamour_queen/models/product_model.dart';
import 'package:glamour_queen/models/report/report_model.dart';
import 'package:glamour_queen/models/report/productReport_model.dart';
import 'package:glamour_queen/pages/journeyplan/reports/base_report_page.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/services/hive/product_hive_service.dart';

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
  final List<Product> _products = [];
  final Map<int, TextEditingController> _quantityControllers = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  final ProductHiveService _hiveService = ProductHiveService();
  static const _cacheExpirationDuration = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadProducts();
  }

  Future<void> _initHiveAndLoadProducts() async {
    try {
      await _hiveService.init();
      await _loadProducts(forceRefresh: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing storage: $e')));
      }
    }
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    try {
      // Always load from Hive first - instant display
      final cachedProducts = await _hiveService.getAllProducts();
      if (cachedProducts.isNotEmpty) {
        _updateProductsList(cachedProducts);
        setState(() => _isLoading = false);
      }

      // Only fetch from API on manual refresh
      if (forceRefresh) {
        setState(() => _isRefreshing = true);

        try {
          final apiProducts = await ApiService.getProducts();
          final validApiProducts = apiProducts
              .where((product) =>
                  product.category.isNotEmpty && product.name.isNotEmpty)
              .map((product) => Product(
                    id: product.id,
                    name: product.name,
                    category_id: product.category_id,
                    category: product.category,
                    description: null,
                    packSize: null,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    imageUrl: null,
                    clientId: null,
                    priceOptions: const [],
                    storeQuantities: const [],
                  ))
              .toList();

          // Update local storage with new data
          await _hiveService.saveProducts(validApiProducts);

          // Update UI with new data
          if (mounted) {
            _updateProductsList(validApiProducts);
          }
        } catch (e) {
          // If API fails, keep showing local data
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Failed to refresh products. Using local data.')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading local products: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _updateProductsList(List<Product> products) {
    // Sort products alphabetically
    products.sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _products.clear();
      _products.addAll(products);

      // Initialize quantity controllers for all products
      for (var product in _products) {
        _quantityControllers.putIfAbsent(
          product.id,
          () => TextEditingController(),
        );
      }
    });
  }

  @override
  void dispose() {
    // Dispose all quantity controllers
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void resetForm() {
    setState(() {
      for (var controller in _quantityControllers.values) {
        controller.clear();
      }
      commentController.clear();
      isSubmitting = false;
    });
  }

  @override
  Future<void> onSubmit() async {
    // Find all products with entered quantities
    final productReports = <ProductReport>[];

    for (var product in _products) {
      final quantityText = _quantityControllers[product.id]?.text ?? '';
      if (quantityText.isNotEmpty) {
        final quantity = int.tryParse(quantityText);
        if (quantity == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter valid quantities')),
          );
          return;
        }

        productReports.add(ProductReport(
          reportId: 0, // Will be set by backend
          productName: product.name,
          quantity: quantity,
          comment: commentController.text,
        ));
      }
    }

    if (productReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter quantities for at least one product')),
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
      productReports: productReports,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Product Availability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isRefreshing
                      ? null
                      : () => _loadProducts(forceRefresh: true),
                  tooltip: 'Refresh Products',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildProductsTable(),
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

  Widget _buildProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Quantity')),
        ],
        rows: _products.map((product) {
          return DataRow(
            cells: [
              DataCell(Text(product.name)),
              DataCell(Text(product.category)),
              DataCell(
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _quantityControllers[product.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

