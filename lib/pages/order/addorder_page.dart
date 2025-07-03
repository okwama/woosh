// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:glamour_queen/models/hive/order_model.dart';
import 'package:glamour_queen/models/outlet_model.dart';
import 'package:glamour_queen/pages/order/product/products_grid_page.dart';
import 'package:glamour_queen/controllers/cart_controller.dart';
import 'package:glamour_queen/services/hive/order_hive_service.dart';

class AddOrderPage extends StatefulWidget {
  final Outlet outlet;
  final OrderModel? order;

  const AddOrderPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  _AddOrderPageState createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  final OrderHiveService _orderHiveService = OrderHiveService();

  @override
  void initState() {
    super.initState();
    _initializeHive();
    // Initialize cart controller if it doesn't exist
    if (!Get.isRegistered<CartController>()) {
      Get.put(CartController());
    }
  }

  Future<void> _initializeHive() async {
    await _orderHiveService.init();
  }

  @override
  Widget build(BuildContext context) {
    // Immediately navigate to products grid page
    return ProductsGridPage(
      outlet: widget.outlet,
      order: widget.order,
    );
  }
}

