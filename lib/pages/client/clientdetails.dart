import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' as ptr;
import 'package:woosh/models/client_payment_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/utils/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:woosh/utils/country_tax_labels.dart';
import 'package:woosh/pages/client/client_stock_page.dart';
import 'package:woosh/services/client_stock_service.dart';

class ClientDetailsPage extends StatefulWidget {
  final Outlet outlet;

  const ClientDetailsPage({super.key, required this.outlet});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  String? _locationDescription;
  List<ClientPayment> _payments = [];
  bool _loadingPayments = false;
  String? _errorMessage;
  final ptr.RefreshController _refreshController = ptr.RefreshController();
  bool _clientStockEnabled = true; // Track if client stock feature is enabled

  @override
  void initState() {
    super.initState();
    _decodeLocation();
    _fetchPayments();
    _checkClientStockFeature();
  }

  Future<void> _decodeLocation() async {
    if (widget.outlet.latitude != null && widget.outlet.longitude != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.outlet.latitude!,
          widget.outlet.longitude!,
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

    setState(() {
      _loadingPayments = true;
      _errorMessage = null;
    });

    try {
      final paymentsData = await ApiService.getClientPayments(widget.outlet.id);
      setState(() {
        _payments = paymentsData.map((e) => ClientPayment.fromJson(e)).toList();
      });
    } catch (e) {
      // Handle server errors silently
      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('Server error during payment fetch - handled silently: $e');
      } else {
        setState(() {
          _errorMessage = 'Failed to load payments. Please try again.';
        });
        _showErrorDialog();
      }
    } finally {
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
    final amountController = TextEditingController();
    String? selectedMethod;
    XFile? pickedFile;
    bool uploading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Client Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'Cheque',
                        child: Text('Cheque'),
                      ),
                      DropdownMenuItem(
                        value: 'Mpesa',
                        child: Text('Mpesa'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank',
                        child: Text('Bank'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final picker = ImagePicker();
                                  final file = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1024,
                                    maxHeight: 1024,
                                    imageQuality: 85,
                                  );
                                  if (file != null) {
                                    setState(() => pickedFile = file);
                                  }
                                } catch (e) {
                                  print('Error picking image: $e');
                                  setState(() {
                                    errorMessage =
                                        'Failed to select image. Please try again.';
                                  });
                                }
                              },
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image'),
                      ),
                      const SizedBox(width: 8),
                      if (pickedFile != null)
                        const Text('Selected',
                            style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: uploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text);
                          if (amount == null || pickedFile == null) {
                            setState(() {
                              errorMessage =
                                  'Please enter a valid amount and select an image.';
                            });
                            return;
                          }

                          if (selectedMethod == null) {
                            setState(() {
                              errorMessage = 'Please select a payment method.';
                            });
                            return;
                          }

                          setState(() {
                            uploading = true;
                            errorMessage = null;
                          });

                          try {
                            File? imageFile;

                            if (kIsWeb) {
                              imageFile = null;
                            } else {
                              imageFile = File(pickedFile!.path);
                            }

                            await ApiService.uploadClientPayment(
                              clientId: widget.outlet.id,
                              amount: amount,
                              imageFile: imageFile ?? File(pickedFile!.path),
                              imageBytes: kIsWeb
                                  ? await pickedFile!.readAsBytes()
                                  : null,
                              method: selectedMethod,
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchPayments();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Payment uploaded successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error uploading payment: $e');
                            // Handle server errors silently
                            if (e.toString().contains('500') ||
                                e.toString().contains('501') ||
                                e.toString().contains('502') ||
                                e.toString().contains('503')) {
                              print(
                                  'Server error during payment upload - handled silently: $e');
                              // Close dialog silently for server errors
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                errorMessage =
                                    'Failed to upload payment. Please try again.';
                                uploading = false;
                              });
                            }
                          }
                        },
                  child: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;

    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: outlet.name,
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
                                        outlet.name,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Balance: Ksh ${outlet.balance != null && outlet.balance!.isNotEmpty ? outlet.balance! : '0'}',
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
                                    value: outlet.address,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.email,
                                    label: 'Email',
                                    value: outlet.email ?? '-',
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
                                    value: outlet.contact ?? '-',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _detailSection(
                                    icon: Icons.badge,
                                    label: CountryTaxLabels.getTaxPinLabel(
                                        widget.outlet.countryId),
                                    value: outlet.taxPin ?? '-',
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
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Add Payment'),
                                onPressed: _showAddPaymentDialog,
                                style: ElevatedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_clientStockEnabled) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.inventory),
                                  label: const Text('Manage Stock'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClientStockPage(
                                          clientId: widget.outlet.id,
                                          clientName: widget.outlet.name,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payments',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _showAddPaymentDialog,
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text('Add',
                                style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
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
      // floatingActionButton: Container(
      //   decoration: GradientDecoration.goldCircular(),
      //   child: FloatingActionButton(
      //     backgroundColor: Colors.transparent,
      //     elevation: 0,
      //     onPressed: () {
      //       Navigator.pop(context);
      //     },
      //     child: const Icon(Icons.arrow_back, color: Colors.white),
      //   ),
      // ),
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
        const Text('Payment History',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<String>(
              value: _selectedStatus,
              items: const [
                DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'PENDING',
                    child: Text('Pending',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'VERIFIED',
                    child: Text('Verified',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'REJECTED',
                    child: Text('Rejected',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
              ],
              onChanged: (val) {
                setState(() => _selectedStatus = val!);
              },
              style: const TextStyle(fontSize: 11, color: Colors.black),
              isDense: true,
              iconSize: 16,
              dropdownColor: Colors.white,
            ),
            DropdownButton<String>(
              value: _selectedSort,
              items: const [
                DropdownMenuItem(
                    value: 'NEWEST',
                    child: Text('Newest',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'OLDEST',
                    child: Text('Oldest',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'AMOUNT_HIGH',
                    child: Text('Amount ?',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'AMOUNT_LOW',
                    child: Text('Amount ?',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
              ],
              onChanged: (val) {
                setState(() => _selectedSort = val!);
              },
              style: const TextStyle(fontSize: 11, color: Colors.black),
              isDense: true,
              iconSize: 16,
              dropdownColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: widget.loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                    ? const Text('No payments yet.',
                        style: TextStyle(fontSize: 11))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredPayments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final p = _filteredPayments[idx];
                          return InkWell(
                            onTap: p.imageUrl != null
                                ? () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Image.network(p.imageUrl!),
                                      ),
                                    )
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side: Image or Icon
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.grey[100],
                                    ),
                                    child: p.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Image.network(
                                              p.imageUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.receipt_long,
                                            size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  // Middle: Payment details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.method ?? 'No Method',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(p.status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _getStatusColor(p.status),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Right side: Date and Amount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        p.date
                                            .toLocal()
                                            .toString()
                                            .split(".")[0],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Ksh ${p.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
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
