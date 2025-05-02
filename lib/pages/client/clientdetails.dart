import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' as ptr;
import 'package:woosh/models/outlet_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/utils/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:woosh/models/clientPayment_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:flutter/rendering.dart';

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

  @override
  void initState() {
    super.initState();
    _decodeLocation();
    _fetchPayments();
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
      final payments = await ApiService.getClientPayments(widget.outlet.id);
      setState(() {
        _payments = payments;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load payments. Please try again.';
      });
      _showErrorDialog();
    } finally {
      setState(() => _loadingPayments = false);
      _refreshController.refreshCompleted();
    }
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
              const Text('• No internet connection'),
              const Text('• Server is temporarily unavailable'),
              const Text('• Database connection issues'),
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
    final _amountController = TextEditingController();
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
                    controller: _amountController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                    source: ImageSource.gallery);
                                if (file != null) {
                                  setState(() => pickedFile = file);
                                }
                              },
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image'),
                      ),
                      const SizedBox(width: 8),
                      if (pickedFile != null)
                        Text('Selected', style: TextStyle(color: Colors.green)),
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
                          final amount =
                              double.tryParse(_amountController.text);
                          if (amount == null || pickedFile == null) {
                            setState(() {
                              errorMessage =
                                  'Please enter a valid amount and select an image.';
                            });
                            return;
                          }

                          setState(() => uploading = true);
                          try {
                            await ApiService.uploadClientPayment(
                              clientId: widget.outlet.id,
                              amount: amount,
                              imageFile: File(pickedFile!.path),
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              _fetchPayments();
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = 'Failed to upload payment: $e';
                              uploading = false;
                            });
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GradientText(
                                'Client Details',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _ticketRow("Client", outlet.name),
                            _ticketRow("Address", outlet.address),
                            _ticketRow("Balance",
                                "Ksh ${outlet.balance != null && outlet.balance!.isNotEmpty ? outlet.balance! : '0'}",
                                highlight: true),
                            if (outlet.email != null &&
                                outlet.email!.isNotEmpty)
                              _ticketRow("Email", outlet.email!),
                            if (outlet.contact != null &&
                                outlet.contact!.isNotEmpty)
                              _ticketRow("Phone", outlet.contact!),
                            if (outlet.taxPin != null &&
                                outlet.taxPin!.isNotEmpty)
                              _ticketRow("KRA PIN", outlet.taxPin!),
                            const SizedBox(height: 14),
                            _dashedDivider(),
                            const SizedBox(height: 14),
                            if (_locationDescription != null)
                              _ticketRow("Location", _locationDescription!,
                                  icon: Icons.place),
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
      floatingActionButton: Container(
        decoration: GradientDecoration.goldCircular(),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back, color: Colors.white),
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
                    child: Text('Amount ↓',
                        style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(
                    value: 'AMOUNT_LOW',
                    child: Text('Amount ↑',
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final p = _filteredPayments[idx];
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            leading: p.imageUrl != null
                                ? Image.network(
                                    p.imageUrl!,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.receipt_long, size: 18),
                            title: Text(
                              'Ksh ${p.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              '${p.date.toLocal().toString().split(".")[0]}\nStatus: ${p.status ?? "-"}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            isThreeLine: true,
                            onTap: p.imageUrl != null
                                ? () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Image.network(p.imageUrl!),
                                      ),
                                    )
                                : null,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
