import 'package:flutter/material.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:woosh/utils/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:woosh/models/clientPayment_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

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
  String _selectedStatus = 'ALL';
  String _selectedSort = 'NEWEST';

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
        _locationDescription = "Location unavailable";
      }
    }
  }

  Future<void> _fetchPayments() async {
    setState(() => _loadingPayments = true);
    try {
      final payments = await ApiService.getClientPayments(widget.outlet.id);
      setState(() {
        _payments = payments;
      });
    } catch (e) {
      // Handle error (show snackbar, etc.)
    } finally {
      setState(() => _loadingPayments = false);
    }
  }

  List<ClientPayment> get _filteredPayments {
    List<ClientPayment> filtered = _selectedStatus == 'ALL'
        ? _payments
        : _payments
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

  Future<void> _showAddPaymentDialog() async {
    final _amountController = TextEditingController();
    XFile? pickedFile;
    bool uploading = false;
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
                        onPressed: () async {
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(_amountController.text);
                          if (amount == null || pickedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enter amount and select image.')),
                            );
                            return;
                          }
                          setState(() => uploading = true);
                          try {
                            await ApiService.uploadClientPayment(
                              clientId: widget.outlet.id,
                              amount: amount,
                              imageFile: File(pickedFile!.path),
                            );
                            Navigator.pop(context);
                            _fetchPayments();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          } finally {
                            setState(() => uploading = false);
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
      ),
      body: Container(
        decoration: BoxDecoration(
          color: appBackground,
        ),
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
                    if (outlet.balance != null && outlet.balance!.isNotEmpty)
                      _ticketRow("Balance", "Ksh ${outlet.balance!}",
                          highlight: true),
                    if (outlet.email != null && outlet.email!.isNotEmpty)
                      _ticketRow("Email", outlet.email!),
                    if (outlet.contact != null && outlet.contact!.isNotEmpty)
                      _ticketRow("Phone", outlet.contact!),
                    if (outlet.taxPin != null && outlet.taxPin!.isNotEmpty)
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _showAddPaymentDialog,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Add Payment'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Payment History Header and Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment History',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All')),
                          DropdownMenuItem(
                              value: 'PENDING', child: Text('Pending')),
                          DropdownMenuItem(
                              value: 'VERIFIED', child: Text('Verified')),
                          DropdownMenuItem(
                              value: 'REJECTED', child: Text('Rejected')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedStatus = val!);
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedSort,
                        items: const [
                          DropdownMenuItem(
                              value: 'NEWEST', child: Text('Newest First')),
                          DropdownMenuItem(
                              value: 'OLDEST', child: Text('Oldest First')),
                          DropdownMenuItem(
                              value: 'AMOUNT_HIGH',
                              child: Text('Amount High-Low')),
                          DropdownMenuItem(
                              value: 'AMOUNT_LOW',
                              child: Text('Amount Low-High')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSort = val!);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _loadingPayments
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredPayments.isEmpty
                          ? const Text('No payments yet.')
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredPayments.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final p = _filteredPayments[idx];
                                return ListTile(
                                  leading: p.imageUrl != null
                                      ? Image.network(
                                          p.imageUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.receipt_long),
                                  title: Text(
                                      'Ksh ${p.amount.toStringAsFixed(2)}'),
                                  subtitle: Text(
                                      '${p.date.toLocal().toString().split(".")[0]}\nStatus: ${p.status ?? "-"}'),
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
          ),
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
