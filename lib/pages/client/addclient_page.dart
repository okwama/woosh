import 'package:flutter/material.dart';
import 'package:woosh/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/client_model.dart';
import 'package:get/get.dart';
import 'package:woosh/services/outlet_service.dart';
import 'package:woosh/utils/country_tax_labels.dart';

class AddClientPage extends StatefulWidget {
  const AddClientPage({super.key});

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  bool _isLocationLoading = false;

  // Add variables for salesRep data
  int? _countryId;
  String? _region;
  int? _regionId;

  @override
  void initState() {
    super.initState();
    // Get location when page loads, so it's ready when user submits
    _getCurrentPosition();
    // Load salesRep data
    _loadSalesRepData();
  }

  void _loadSalesRepData() {
    final box = GetStorage();
    final salesRep = box.read('salesRep');

    if (salesRep != null && salesRep is Map<String, dynamic>) {
      setState(() {
        _countryId = salesRep['countryId'];
        _region = salesRep['region'];
        _regionId = salesRep['region_id'];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _kraPinController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Method to get the current device position
  Future<void> _getCurrentPosition() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return;
        }
      }

      // Check if services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        return;
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Store position for later use
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocationLoading = false;
        });
        print('Got position: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final outlet = await ApiService.createOutlet(
          name: _nameController.text,
          address: _addressController.text,
          taxPin:
              _kraPinController.text.isEmpty ? null : _kraPinController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          contact: _phoneController.text,
          latitude: _currentPosition?.latitude ?? 0.0,
          longitude: _currentPosition?.longitude ?? 0.0,
          countryId: _countryId,
          region: _region,
          regionId: _regionId,
          clientType: 1,
        );

        // Notify the OutletService about the new outlet
        final outletService = Get.find<OutletService>();
        await outletService.addOutlet(outlet);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client added successfully'),
              duration: Duration(seconds: 2),
            ),
          );

          // Return true to indicate successful addition
          Get.back(result: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add client: $e'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Client'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Client Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Please enter client name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kraPinController,
                      decoration: InputDecoration(
                        labelText: CountryTaxLabels.getTaxPinLabel(_countryId),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Please enter phone number'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Please enter address'
                          : null,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Add Client'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
