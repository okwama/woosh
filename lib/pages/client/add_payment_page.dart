import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/utils/app_theme.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddPaymentPage extends StatefulWidget {
  final int clientId;
  final String clientName;

  const AddPaymentPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<AddPaymentPage> createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedMethod;
  XFile? _pickedFile;
  bool _isUploading = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _paymentMethods = ['Bank', 'Mpesa'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() => _pickedFile = file);
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _errorMessage = 'Failed to select image. Please try again.';
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || _pickedFile == null) {
      setState(() {
        _errorMessage = 'Please enter a valid amount and select an image.';
      });
      return;
    }

    if (_selectedMethod == null) {
      setState(() {
        _errorMessage = 'Please select a payment method.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      print('\n=== 📤 PAYMENT UPLOAD DEBUG ===');
      print('📱 Client ID: ${widget.clientId}');
      print('📱 Client Name: ${widget.clientName}');
      print('📱 Amount: $amount');
      print('📱 Method: $_selectedMethod');
      print('📱 File selected: ${_pickedFile != null}');

      File? imageFile;

      if (kIsWeb) {
        print('🌐 Web platform detected');
        imageFile = null;
      } else {
        print('📱 Mobile platform detected');
        imageFile = File(_pickedFile!.path);
      }

      print('🚀 Calling ApiService.uploadClientPayment...');
      await ApiService.uploadClientPayment(
        clientId: widget.clientId,
        amount: amount,
        imageFile: imageFile ?? File(_pickedFile!.path),
        imageBytes: kIsWeb ? await _pickedFile!.readAsBytes() : null,
        method: _selectedMethod!,
      );

      print('✅ Payment upload successful');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Payment uploaded successfully'),
              ],
            ),
            backgroundColor: goldStart,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading payment: $e');

      if (e.toString().contains('500') ||
          e.toString().contains('501') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        print('⚠️ Server error during payment upload - handled silently: $e');
        Navigator.pop(context);
      } else {
        print('❌ Non-server error - showing error message');
        setState(() {
          _errorMessage = 'Failed to upload payment. Please try again.';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Add Payment',
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SlideTransition(
            position: _slideAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Client Info Card
                  CreamGradientCard(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: GradientDecoration.goldCircular(),
                          child: const Icon(
                            Icons.person_outline,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.clientName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: blackColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: goldStart.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ID: ${widget.clientId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: goldStart,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Compact Payment Form
                  CreamGradientCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: GradientDecoration.goldCircular(),
                              child: const Icon(
                                Icons.payment,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Payment Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: blackColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Compact Amount Field
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: blackColor,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount Paid',
                            labelStyle: TextStyle(
                              color: accentGrey,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(6),
                              decoration: GradientDecoration.goldCircular(),
                              child: const Icon(
                                Icons.attach_money,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: goldStart.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: goldStart, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid amount';
                            }
                            if (double.parse(value) <= 0) {
                              return 'Amount must be greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Compact Payment Method Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: blackColor,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Payment Method',
                            labelStyle: TextStyle(
                              color: accentGrey,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(6),
                              decoration: GradientDecoration.goldCircular(),
                              child: const Icon(
                                Icons.account_balance,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: goldStart.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: goldStart, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: method == 'Mpesa'
                                          ? Colors.orange.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      method == 'Mpesa'
                                          ? Icons.phone_android
                                          : Icons.account_balance,
                                      size: 14,
                                      color: method == 'Mpesa'
                                          ? Colors.orange
                                          : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(method),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMethod = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a payment method';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Compact Image Upload Section
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: GradientDecoration.goldCircular(),
                              child: const Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Payment Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: blackColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: _pickedFile != null
                                ? goldGradient
                                : LinearGradient(
                                    colors: [
                                      goldStart.withOpacity(0.1),
                                      goldMiddle1.withOpacity(0.1),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _pickedFile != null
                                  ? Colors.transparent
                                  : goldStart.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_pickedFile != null
                                        ? goldStart
                                        : goldStart)
                                    .withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _pickedFile != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        File(_pickedFile!.path),
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: ScaleTransition(
                                        scale: _pulseAnimation,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : InkWell(
                                  onTap: _pickImage,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration:
                                              GradientDecoration.goldCircular(),
                                          child: const Icon(
                                            Icons.add_photo_alternate,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to select receipt image',
                                          style: TextStyle(
                                            color: goldStart,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _pickedFile!.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.edit,
                                        size: 14, color: Colors.green),
                                    label: const Text(
                                      'Change',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Compact Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Compact Submit Button
                  GoldGradientButton(
                    onPressed: _isUploading ? () {} : () => _submitPayment(),
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Uploading...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Upload Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
