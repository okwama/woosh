import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' as ptr;
import 'package:woosh/models/clients/client_payment_model.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/models/clients/outlet_model.dart';
import 'package:woosh/pages/client/viewclient_page.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/utils/country_tax_labels.dart';
import 'package:woosh/pages/client/client_stock_page.dart';
import 'package:woosh/services/client_stock_service.dart';
import 'package:woosh/pages/client/add_payment_page.dart';

class ClientDetailsPage extends StatefulWidget {
  final Client client;

  const ClientDetailsPage(
      {super.key, required this.client, required Outlet outlet});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  String? _locationDescription;
  List<ClientPayment> _payments = [];
  bool _loadingPayments = false;
  String? _errorMessage;
  final ptr.RefreshController _refreshController = ptr.RefreshController();
  bool _clientStockEnabled = false; // Track if client stock feature is enabled

  @override
  void initState() {
    super.initState();
    _decodeLocation();
    _fetchPayments();
    _checkClientStockFeature();
  }

  Future<void> _decodeLocation() async {
    if (widget.client.latitude != null && widget.client.longitude != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.client.latitude!,
          widget.client.longitude!,
        );
        final placemark = placemarks.first;
        setState(() {
          _locationDescription =
              "${placemark.street}, ${placemark.locality}, ${placemark.country}";
        });
      } catch (e) {
        setState(() {
          _locationDescription = "Location unavailable";
        });
      }
    }
  }

  Future<void> _fetchPayments() async {
    if (_loadingPayments) return;

    print('\n=== 🔍 PAYMENT FETCH DEBUG ===');
    print('📱 Client ID: ${widget.client.id}');
    print('📱 Client Name: ${widget.client.name}');
    print('📱 Loading State: $_loadingPayments');

    setState(() {
      _loadingPayments = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Calling ApiService.getClientPayments...');
      final paymentsData = await ApiService.getClientPayments(widget.client.id);

      print('✅ API Response received:');
      print('📊 Payments count: ${paymentsData.length}');
      print('📊 Raw payments data: ${paymentsData.toString()}');

      setState(() {
        _payments = paymentsData.map((e) {
          print('🔄 Converting payment: ${e.toString()}');
          return ClientPayment.fromJson(e);
        }).toList();
      });

      print('✅ Payments converted successfully:');
      print('📊 Final payments count: ${_payments.length}');
      for (int i = 0; i < _payments.length; i++) {
        final payment = _payments[i];
        print('📋 Payment ${i + 1}:');
        print('   - ID: ${payment.id}');
        print('   - Client ID: ${payment.clientId}');
        print('   - User ID: ${payment.userId}');
        print('   - Amount: ${payment.amount}');
        print('   - Method: ${payment.method}');
        print('   - Status: ${payment.status}');
        print('   - Date: ${payment.date}');
        print('   - Image URL: ${payment.imageUrl}');
      }
    } catch (e) {
      print('❌ Error during payment fetch:');
      print('🚨 Error type: ${e.runtimeType}');
      print('🚨 Error message: ${e.toString()}');
      print('🚨 Error stack trace: ${StackTrace.current}');

      // Handle server errors silently
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('⚠️ Server error during payment fetch - handled silently: $e');
      } else {
        print('❌ Non-server error - showing error dialog');
        setState(() {
          _errorMessage = 'Failed to load payments. Please try again.';
        });
        _showErrorDialog();
      }
    } finally {
      print('🏁 Payment fetch completed');
      print('📊 Final loading state: false');
      setState(() => _loadingPayments = false);
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _checkClientStockFeature() async {
    try {
      final isEnabled = await ClientStockService.isFeatureEnabled();
      setState(() {
        _clientStockEnabled = isEnabled;
      });
    } catch (e) {
      print('Error checking client stock feature status: $e');
      // Default to enabled if we can't check the status or endpoint doesn't exist
      setState(() {
        _clientStockEnabled = true;
      });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _fetchPayments(),
      _checkClientStockFeature(),
    ]);
  }

  void _showErrorDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unable to load payments. This could be due to:'),
              const SizedBox(height: 8),
              const Text('? No internet connection'),
              const Text('? Server is temporarily unavailable'),
              const Text('? Database connection issues'),
              const SizedBox(height: 16),
              const Text('Would you like to retry?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _fetchPayments();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showAddPaymentDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPaymentPage(
          clientId: widget.client.id,
          clientName: widget.client.name,
        ),
      ),
    );

    // Refresh payments if payment was successfully uploaded
    if (result == true) {
      _fetchPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: client.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPayments,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CreamGradientCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  child: Icon(Icons.person, size: 24),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.name,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Balance: Ksh ${client.balance != null ? client.balance! : '0'}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.home,
                                    label: 'Address',
                                    value: client.address ?? '-',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.email,
                                    label: 'Email',
                                    value: client.email ?? '-',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.phone,
                                    label: 'Phone',
                                    value: client.contact ?? '-',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.badge,
                                    label: CountryTaxLabels.getTaxPinLabel(
                                        client.countryId),
                                    value: client.taxPin ?? '-',
                                  ),
                                ),
                              ],
                            ),
                            if (_locationDescription != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _detailSection(
                                      icon: Icons.place,
                                      label: 'Location',
                                      value: _locationDescription!,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                      child:
                                          SizedBox()), // Empty to keep layout
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon:
                                        const Icon(Icons.upload_file, size: 20),
                                    label: const Text(
                                      'Add Payment',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: _showAddPaymentDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                                // Temporarily hidden - will be used later
                                // if (_clientStockEnabled) ...[
                                //   const SizedBox(width: 12),
                                //   Expanded(
                                //     child: ElevatedButton.icon(
                                //       icon:
                                //           const Icon(Icons.inventory, size: 20),
                                //       label: const Text(
                                //         'Manage Stock',
                                //         style: TextStyle(
                                //           fontSize: 14,
                                //           fontWeight: FontWeight.w600,
                                //         ),
                                //       ),
                                //       onPressed: () {
                                //         Navigator.push(
                                //           context,
                                //           MaterialPageRoute(
                                //             builder: (context) =>
                                //                 ClientStockPage(
                                //               clientId: client.id,
                                //               clientName: client.name,
                                //             ),
                                //           ),
                                //         );
                                //       },
                                //       style: ElevatedButton.styleFrom(
                                //         backgroundColor: Colors.orange,
                                //         foregroundColor: Colors.white,
                                //         padding: const EdgeInsets.symmetric(
                                //             vertical: 12),
                                //         shape: RoundedRectangleBorder(
                                //           borderRadius:
                                //               BorderRadius.circular(12),
                                //         ),
                                //         elevation: 2,
                                //       ),
                                //     ),
                                //   ),
                                // ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payment History Section
                      PaymentHistoryCard(
                        payments: _payments,
                        loading: _loadingPayments,
                        onRefresh: _fetchPayments,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _showAddPaymentDialog,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _ticketRow(String label, String value,
      {bool highlight = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 18, color: goldMiddle2),
            ),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: "$label: ",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: blackColor,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          highlight ? FontWeight.bold : FontWeight.normal,
                      color: highlight ? goldStart : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        20,
        (_) => Container(
          width: 4,
          height: 1.5,
          color: goldMiddle2.withOpacity(0.6),
        ),
      ),
    );
  }

  // Helper widget for a compact detail section
  Widget _detailSection(
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentHistoryCard extends StatefulWidget {
  final List<ClientPayment> payments;
  final bool loading;
  final Function() onRefresh;

  const PaymentHistoryCard({
    super.key,
    required this.payments,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<PaymentHistoryCard> createState() => _PaymentHistoryCardState();
}

class _PaymentHistoryCardState extends State<PaymentHistoryCard> {
  String _selectedStatus = 'ALL';
  String _selectedSort = 'NEWEST';

  List<ClientPayment> get _filteredPayments {
    List<ClientPayment> filtered = _selectedStatus == 'ALL'
        ? widget.payments
        : widget.payments
            .where((p) => (p.status ?? '').toUpperCase() == _selectedStatus)
            .toList();
    switch (_selectedSort) {
      case 'NEWEST':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'OLDEST':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'AMOUNT_HIGH':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'AMOUNT_LOW':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payment History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_filteredPayments.length} payments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filters Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Row(
                          children: [
                            Icon(Icons.list, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            const Text('All Status'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'PENDING',
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('Pending'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'VERIFIED',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text('Verified'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'REJECTED',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Rejected'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStatus = val!);
                    },
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSort,
                  items: [
                    DropdownMenuItem(
                      value: 'NEWEST',
                      child: Row(
                        children: [
                          Icon(Icons.sort, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Newest'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'OLDEST',
                      child: Row(
                        children: [
                          Icon(Icons.sort, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Oldest'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'AMOUNT_HIGH',
                      child: Row(
                        children: [
                          Icon(Icons.trending_up,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Amount High'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'AMOUNT_LOW',
                      child: Row(
                        children: [
                          Icon(Icons.trending_down,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text('Amount Low'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSort = val!);
                  },
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Payment List
        if (widget.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_filteredPayments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.payment,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No payments yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Payments will appear here once uploaded',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredPayments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final p = _filteredPayments[idx];
              return _buildPaymentCard(p);
            },
          ),
      ],
    );
  }

  Widget _buildPaymentCard(ClientPayment payment) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: payment.imageUrl != null
            ? () => _showPaymentImage(payment.imageUrl!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Payment Method Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getMethodColor(payment.method).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getMethodIcon(payment.method),
                  color: _getMethodColor(payment.method),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Payment Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payment.method ?? 'Unknown Method',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Ksh ${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(payment.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            payment.status ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(payment.status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(payment.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (payment.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.image,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view receipt',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.grey[100],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Payment Receipt',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMethodColor(String? method) {
    switch (method?.toUpperCase()) {
      case 'MPESA':
        return Colors.orange;
      case 'BANK':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getMethodIcon(String? method) {
    switch (method?.toUpperCase()) {
      case 'MPESA':
        return Icons.phone_android;
      case 'BANK':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'VERIFIED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
