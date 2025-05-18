import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/models/orderitem_model.dart';
import 'package:woosh/controllers/cart_controller.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/pages/order/product/products_grid_page.dart';
import 'package:woosh/utils/image_utils.dart';
import 'package:woosh/models/store_model.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class CartPage extends StatefulWidget {
  final Outlet outlet;
  final Order? order;

  const CartPage({
    super.key,
    required this.outlet,
    this.order,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with WidgetsBindingObserver {
  final CartController cartController = Get.find<CartController>();
  final AuthController authController = Get.find<AuthController>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Store?> selectedStore = Rx<Store?>(null);
  final RxList<Store> availableStores = <Store>[].obs;
  final Rx<dynamic> selectedImage =
      Rx<dynamic>(null); // For storing selected image
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStores();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    ImageCache().clear();
    ImageCache().clearLiveImages();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await ApiService.getStores();
      print('Total stores received: ${stores.length}');

      // Get user's region and country from GetStorage
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      final userRegionId = salesRep?['region_id'];
      final userCountryId = salesRep?['countryId'];

      print(
          'User context - Region ID: $userRegionId, Country ID: $userCountryId');
      print('Outlet country ID: ${widget.outlet.countryId}');

      // Filter stores based on user's country first, then outlet's country
      final filteredStores = stores.where((store) {
        print('Checking store: ${store.name} (Country ID: ${store.countryId})');

        // First priority: User's country
        if (userCountryId != null) {
          final matches = store.countryId == userCountryId;
          print(
              'Store ${store.name} ${matches ? 'matches' : 'does not match'} user country $userCountryId');
          return matches;
        }

        // Second priority: Outlet's country
        if (widget.outlet.countryId != null) {
          final matches = store.countryId == widget.outlet.countryId;
          print(
              'Store ${store.name} ${matches ? 'matches' : 'does not match'} outlet country ${widget.outlet.countryId}');
          return matches;
        }

        // If no country filters available, show all active stores
        final isActive = store.status == 0;
        print(
            'No country filter - Store ${store.name} is ${isActive ? 'active' : 'inactive'}');
        return isActive;
      }).toList();

      print('Filtered stores: ${filteredStores.length}');
      print(
          'Available stores: ${filteredStores.map((s) => s.name).join(', ')}');

      availableStores.value = filteredStores;

      if (filteredStores.isNotEmpty) {
        selectedStore.value = filteredStores.first;
        print('Selected store: ${selectedStore.value?.name}');
      } else {
        // Show a message if no stores are available for the country
        Get.snackbar(
          'No Stores Available',
          'There are no stores available in your country. Please contact support.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error loading stores: $e');
      Get.snackbar(
        'Error',
        'Failed to load stores. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showOrderSuccessDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Order Successful'),
          ],
        ),
        content: const Text('Your order has been placed successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.offNamed('/home'); // Go to home
            },
            child: const Text('Back to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.offNamed('/orders'); // Go to orders page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Orders'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compress image
      );

      if (image != null) {
        selectedImage.value = image;
      }
    } catch (e) {
      print('Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> placeOrder() async {
    try {
      isLoading.value = true;

      if (selectedStore.value == null) {
        Get.snackbar(
          'Error',
          'Please select a store',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final outletId = widget.outlet.id;

      if (cartController.items.isEmpty) {
        Get.snackbar(
          'Error',
          'Cart is empty',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Prepare order items with store information
      final orderItems = cartController.items.map((item) {
        if (item.product == null) {
          throw Exception('Invalid product in cart');
        }
        if (item.quantity <= 0) {
          throw Exception('Invalid quantity for ${item.product!.name}');
        }
        if (item.priceOptionId == null) {
          throw Exception('No price option selected for ${item.product!.name}');
        }

        // Check stock availability for the selected store
        final storeQuantity =
            item.product!.getQuantityForStore(selectedStore.value!.id);
        if (storeQuantity < item.quantity) {
          throw Exception(
              'Insufficient stock for ${item.product!.name} in ${selectedStore.value!.name}');
        }

        return {
          'productId': item.product!.id,
          'quantity': item.quantity,
          'priceOptionId': item.priceOptionId,
          'storeId': selectedStore.value!.id,
        };
      }).toList();

      // Create or update order
      final orderId = widget.order?.id;
      final response = orderId == null
          ? await ApiService.createOrder(
              clientId: outletId,
              items: orderItems,
              imageFile: selectedImage.value,
            )
          : await ApiService.updateOrder(
              orderId: orderId,
              orderItems: orderItems,
            );

      // Check for outstanding balance
      if (response != null) {
        if (response is Map<String, dynamic> && response['hasOutstandingBalance'] == true) {
          final dialog = response['dialog'];
          await Get.dialog(
            AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(dialog?['title'] ?? 'Outstanding Balance'),
                ],
              ),
              content: Text(dialog?['message'] ?? 'This client has an outstanding balance.'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
                    // Proceed with order despite balance warning
                    _processOrderSuccess();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Proceed Anyway'),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          return;
        } else if (response is Order) {
          _processOrderSuccess();
        }
      }
    } catch (e) {
      print('Error placing order: $e');
      handleOrderError(e);
    } finally {
      isLoading.value = false;
    }
  }

  void _processOrderSuccess() {
    cartController.clear();
    selectedImage.value = null;
    _showOrderSuccessDialog();
  }

  void handleOrderError(dynamic error) async {
    String errorMessage = error.toString();
    print('Order error: $errorMessage');

    // If the response was a success but the returned data was incomplete,
    // ApiService.createOrder will now show a success dialog and return null.
    // So, here, we only need to handle actual errors (like stock issues).
    if (errorMessage.contains('Insufficient stock')) {
      final RegExp regex = RegExp(r'Insufficient stock for product (.+)');
      final match = regex.firstMatch(errorMessage);
      final productName = match?.group(1) ?? 'Unknown Product';

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Out of Stock'),
            content: Text('Insufficient stock for $productName'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else if (errorMessage.contains('Order cancelled by user')) {
      // User cancelled the order due to balance warning
      Get.snackbar(
        'Order Cancelled',
        'The order was cancelled due to balance warning',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } else {
      // Handle other errors
      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.off(() => ProductsGridPage(
                  outlet: widget.outlet,
                  order: widget.order,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index, OrderItem item) {
    final packSize = item.product?.packSize;
    final totalPieces = (packSize != null) ? item.quantity * packSize : null;
    return Card(
      key: ValueKey('cart_item_${index}_${item.productId}'),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.product?.imageUrl != null
                  ? Image.network(
                      ImageUtils.getGridUrl(item.product!.imageUrl!),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.name ?? 'Unknown Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.priceOptionId != null)
                    Text(
                      'Price Option: ${item.product?.priceOptions.firstWhereOrNull((po) => po.id == item.priceOptionId)?.option ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    'Quantity: ${item.quantity}${packSize != null ? ' pack(s) ($totalPieces pcs)' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final newQuantity = item.quantity - 1;
                        if (newQuantity > 0) {
                          cartController.updateItemQuantity(item, newQuantity);
                        } else {
                          cartController.removeItem(item);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final newQuantity = item.quantity + 1;
                        if (item.product?.storeQuantities == null ||
                            newQuantity <=
                                item.product!.storeQuantities.first.quantity) {
                          cartController.updateItemQuantity(item, newQuantity);
                        } else {
                          Get.snackbar(
                            'Error',
                            'Cannot exceed available stock',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.red[400],
                            colorText: Colors.white,
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
                if (item.priceOptionId != null)
                  Text(
                    'Ksh ${(item.product?.priceOptions.firstWhereOrNull((po) => po.id == item.priceOptionId)?.value ?? 0) * item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Obx(() {
        final totalItems =
            cartController.items.fold(0, (sum, item) => sum + item.quantity);
        final totalAmount = cartController.totalAmount;
        final totalPieces = cartController.items.fold(
            0,
            (sum, item) =>
                sum +
                ((item.product?.packSize != null)
                    ? item.quantity * item.product!.packSize!
                    : 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$totalItems',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            if (totalPieces > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pieces',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$totalPieces',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Ksh ${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() {
        final loading = isLoading.value;
        final hasItems = cartController.items.isNotEmpty;

        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: !loading
                    ? () => Get.off(() => ProductsGridPage(
                          outlet: widget.outlet,
                          order: widget.order,
                        ))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add More'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: (!loading && hasItems) ? placeOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Processing...'),
                        ],
                      )
                    : Text(
                        widget.order == null ? 'Place Order' : 'Update Order',
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Cart' : 'Edit Order'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Add image attachment button to app bar
          Obx(() {
            if (selectedImage.value != null) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                    tooltip: 'Change Image',
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _pickImage,
                tooltip: 'Attach Image',
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Store Selection Dropdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Store',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Store>(
                    value: selectedStore.value,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items: availableStores.map((store) {
                      return DropdownMenuItem(
                        value: store,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (store.region != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${store.region!.name}${store.region!.country != null ? ', ${store.region!.country!.name}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Store? newValue) {
                      if (newValue != null) {
                        selectedStore.value = newValue;
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a store';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (errorMessage.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  cartController.items.isEmpty
                      ? _buildEmptyCart()
                      : ListView.builder(
                          itemCount: cartController.items.length,
                          itemBuilder: (context, index) {
                            return _buildCartItem(
                                index, cartController.items[index]);
                          },
                        ),
                  // Show image preview if an image is selected
                  if (selectedImage.value != null)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? FutureBuilder<Uint8List>(
                                        future:
                                            selectedImage.value.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            );
                                          } else {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                        },
                                      )
                                    : Image.file(
                                        File(selectedImage.value.path),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => selectedImage.value = null,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildTotalSection(),
          ],
        );
      }),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
