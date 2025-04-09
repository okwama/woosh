// Add/Edit Order Page
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/pages/order/products_grid_page.dart';
import 'package:woosh/controllers/cart_controller.dart';

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
  @override
  void initState() {
    super.initState();
    // Initialize cart controller if it doesn't exist
    if (!Get.isRegistered<CartController>()) {
      Get.put(CartController());
    }
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
