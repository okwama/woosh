import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/models/uplift_sale_model.dart';
import 'package:woosh/controllers/uplift_sale_controller.dart';
import 'package:woosh/utils/date_utils.dart' as custom_date;
import 'package:woosh/utils/currency_utils.dart';

class UpliftSalesPage extends StatefulWidget {
  const UpliftSalesPage({super.key});

  @override
  State<UpliftSalesPage> createState() => _UpliftSalesPageState();
}

class _UpliftSalesPageState extends State<UpliftSalesPage> {
  late final UpliftSaleController _controller;
  final RxString _selectedStatus = 'all'.obs;
  final Rx<DateTime?> _startDate = Rx<DateTime?>(null);
  final Rx<DateTime?> _endDate = Rx<DateTime?>(null);
  final RxInt _selectedClientId = RxInt(0);
  final RxBool _isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(UpliftSaleController());
    _loadSales();
  }

  Future<void> _loadSales() async {
    _isLoading.value = true;
    await _controller.loadSales(
      status: _selectedStatus.value == 'all' ? null : _selectedStatus.value,
      startDate: _startDate.value,
      endDate: _endDate.value,
      clientId: _selectedClientId.value == 0 ? null : _selectedClientId.value,
    );
    _isLoading.value = false;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate.value ?? DateTime.now()
          : _endDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (isStartDate) {
        _startDate.value = picked;
      } else {
        _endDate.value = picked;
      }
      _loadSales();
    }
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => DropdownButtonFormField<String>(
                  value: _selectedStatus.value,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'all',
                    'pending',
                    'completed',
                    'cancelled',
                  ].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status.capitalizeFirst!),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      _selectedStatus.value = value;
                      _loadSales();
                    }
                  },
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Obx(() => TextButton(
                        onPressed: () => _selectDate(context, true),
                        child: Text(
                          _startDate.value != null
                              ? custom_date.DateUtils.formatDate(
                                  _startDate.value!)
                              : 'Select Start Date',
                        ),
                      )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(() => TextButton(
                        onPressed: () => _selectDate(context, false),
                        child: Text(
                          _endDate.value != null
                              ? custom_date.DateUtils.formatDate(
                                  _endDate.value!)
                              : 'Select End Date',
                        ),
                      )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleItem(UpliftSale sale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to sale details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sale #${sale.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sale.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sale.status.capitalizeFirst!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sale.client != null) ...[
                Text(
                  'Client: ${sale.client!.name}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Items: ${sale.items.length}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${CurrencyUtils.format(sale.totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${custom_date.DateUtils.formatDateTime(sale.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uplift Sales'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Text(
                    _controller.errorMessage.value,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (_controller.sales.isEmpty) {
                return const Center(
                  child: Text('No uplift sales found'),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadSales,
                child: ListView.builder(
                  itemCount: _controller.sales.length,
                  itemBuilder: (context, index) {
                    final sale = _controller.sales[index];
                    return _buildSaleItem(sale);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
