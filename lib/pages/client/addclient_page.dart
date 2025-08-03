import 'package:flutter/material.dart';
import 'package:woosh/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/hive/client_model.dart';
import 'package:get/get.dart';
import 'package:woosh/services/client/client_service.dart';
import 'package:woosh/utils/country_tax_labels.dart';
import 'package:woosh/services/hive/client_hive_service.dart';
import 'package:woosh/models/clients/outlet_model.dart';
import 'package:woosh/models/clients/client_model.dart';

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

  // Check for duplicates before submitting
  Future<bool> _checkForDuplicates() async {
    try {
      final clientHiveService = Get.find<ClientHiveService>();
      final existingClients = clientHiveService.getAllClients();

      // Check for exact name match (case-insensitive)
      ClientModel? duplicate;
      try {
        duplicate = existingClients.firstWhere(
          (client) =>
              client.name.toLowerCase() == _nameController.text.toLowerCase(),
        );
      } catch (e) {
        duplicate = null; // No duplicate found
      }

      if (duplicate != null) {
        return await _showDuplicateWarning(duplicate);
      }

      return true; // No duplicate found, continue
    } catch (e) {
      print('Error checking for duplicates: $e');
      return true; // Continue on error
    }
  }

  // Show duplicate warning dialog
  Future<bool> _showDuplicateWarning(ClientModel existingClient) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Client Already Exists'),
            content: Text(
                'A client with name "${existingClient.name}" already exists.\n\n'
                'Do you want to add this client anyway?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Anyway'),
              ),
            ],
          ),
        ) ??
        false;
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
      // Check for duplicates before submitting
      final shouldContinue = await _checkForDuplicates();
      if (!shouldContinue) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        print('🚀 Creating new client...');
        print('📊 Client data:');
        print('   - Name: ${_nameController.text}');
        print('   - Address: ${_addressController.text}');
        print('   - Phone: ${_phoneController.text}');
        print('   - Email: ${_emailController.text}');
        print('   - Tax Pin: ${_kraPinController.text}');
        print(
            '   - Location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
        print('   - Country ID: $_countryId');
        print('   - Region: $_region');
        print('   - Region ID: $_regionId');

        final outlet = await ApiService.createOutlet(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          taxPin: _kraPinController.text.trim().isEmpty
              ? null
              : _kraPinController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          contact: _phoneController.text.trim(),
          latitude: _currentPosition?.latitude ?? 0.0,
          longitude: _currentPosition?.longitude ?? 0.0,
          countryId: _countryId,
          region: _region,
          regionId: _regionId,
          clientType: 1, // Default client type
        );

        print('✅ Client created successfully:');
        print('   - ID: ${outlet.id}');
        print('   - Name: ${outlet.name}');

        // Notify the ClientService about the new client
        await ClientService.createClient({
          'id': outlet.id,
          'name': outlet.name,
          'address': outlet.address,
          'contact': outlet.contact ?? '',
          'email': outlet.email,
          'latitude': outlet.latitude,
          'longitude': outlet.longitude,
          'regionId': outlet.regionId,
          'region': outlet.region,
          'countryId': outlet.countryId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Client added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Return true to indicate successful addition
          Get.back(result: true);
        }
      } catch (e) {
        print('❌ Error creating client: $e');

        if (mounted) {
          String errorMessage = 'Unable to add client. Please try again.';

          // Handle specific error cases
          if (e.toString().contains('409')) {
            errorMessage = 'A client with this name already exists.';
          } else if (e.toString().contains('400')) {
            errorMessage = 'Please check your input and try again.';
          } else if (e.toString().contains('401')) {
            errorMessage = 'Authentication required. Please log in again.';
          } else if (e.toString().contains('500') ||
              e.toString().contains('502') ||
              e.toString().contains('503')) {
            errorMessage =
                'Server is temporarily unavailable. Please try again later.';
          }

          setState(() {
            _error = errorMessage;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
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
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter client name';
                        }
                        if (value.trim().length < 2) {
                          return 'Client name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kraPinController,
                      decoration: InputDecoration(
                        labelText: CountryTaxLabels.getTaxPinLabel(_countryId),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.receipt),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        if (value.trim().length < 5) {
                          return 'Please enter a detailed address';
                        }
                        return null;
                      },
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    
                    // Location Status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isLocationLoading 
                            ? Colors.blue.withOpacity(0.1)
                            : _currentPosition != null 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isLocationLoading 
                              ? Colors.blue.withOpacity(0.3)
                              : _currentPosition != null 
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLocationLoading 
                                ? Icons.location_searching
                                : _currentPosition != null 
                                    ? Icons.location_on
                                    : Icons.location_off,
                            color: _isLocationLoading 
                                ? Colors.blue
                                : _currentPosition != null 
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLocationLoading 
                                      ? 'Getting location...'
                                      : _currentPosition != null 
                                          ? 'Location captured'
                                          : 'Location not available',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_currentPosition != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isLocationLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
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
