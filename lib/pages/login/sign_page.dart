import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/controllers/auth_controller.dart';
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
<<<<<<< HEAD
  final TextEditingController _countryController =
      TextEditingController(text: 'Kenya');
=======
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  final TextEditingController _countryIdController =
      TextEditingController(text: '1');
  final TextEditingController _regionIdController =
      TextEditingController(text: '1');
  final TextEditingController _regionController =
      TextEditingController(text: 'Nairobi');
  final TextEditingController _routeIdController =
      TextEditingController(text: '1');
  final TextEditingController _routeController =
<<<<<<< HEAD
      TextEditingController(text: 'Nairobi');
  String? _selectedRole = 'SALES_REP';
  String? _selectedCountry = 'Kenya';
  final TextEditingController _departmentController = TextEditingController();
=======
      TextEditingController(text: 'Kilimani');
  String? _selectedRole = 'SALES_REP';
  String? _selectedCountry = 'Kenya';
  int _selectedCountryId = 1;
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthController _authController = Get.find<AuthController>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Country data
  final Map<String, Map<String, dynamic>> _countries = {
    'Kenya': {
      'id': 1,
      'regions': ['Nairobi', 'Mombasa', 'Kisumu', 'Nakuru']
    },
    'Tanzania': {
      'id': 2,
      'regions': ['Dar es Salaam', 'Arusha', 'Mwanza', 'Dodoma']
    },
    'Nigeria': {
      'id': 3,
      'regions': ['Lagos', 'Abuja', 'Kano', 'Port Harcourt']
    },
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countryIdController.dispose();
    _regionIdController.dispose();
    _regionController.dispose();
    _routeIdController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d{10,12}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _onCountryChanged(String? country) {
    if (country != null && _countries.containsKey(country)) {
      setState(() {
        _selectedCountry = country;
        _countryController.text = country;
        _countryIdController.text = _countries[country]!['id'].toString();

        // Update region to first available region for selected country
        final regions = _countries[country]!['regions'] as List<String>;
        _regionController.text = regions.first;
        _routeController.text = regions.first;
      });
    }
  }

  void _showToast(String message, bool isError) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: isError ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: isError ? 3 : 1,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'password': _passwordController.text,
        'country': _selectedCountry,
        'countryId': _selectedCountryId,
        'region_id': int.tryParse(_regionIdController.text) ?? 1,
        'region': _regionController.text,
        'route_id': int.tryParse(_routeIdController.text) ?? 1,
        'route': _routeController.text,
        'role': _selectedRole,
<<<<<<< HEAD
        'department':
            _selectedRole == 'MANAGER' ? _departmentController.text : null,
=======
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
      };

      final response = await _apiService.register(userData);

      if (response['success']) {
        _showToast('Account created successfully!', false);
        Get.back(); // Return to login page
      } else {
        _showToast(response['message'] ?? 'Registration failed', true);
      }
    } catch (e) {
      _showToast(e.toString(), true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? screenWidth * 0.25 : 16.0; // Reduced padding
    final maxFormWidth = isTablet ? 500.0 : double.infinity;

    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
<<<<<<< HEAD
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              // Reduced top spacing
              SizedBox(height: screenHeight * 0.01),
=======
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      margin: const EdgeInsets.only(bottom: 30),
                      decoration: GradientDecoration.goldCircular(),
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(15),
                        child:
                            Image.asset('assets/glam.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2

              // Main content card
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                decoration: BoxDecoration(
                  color: appBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 2,
                    color: Colors.transparent,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goldStart.withOpacity(0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
<<<<<<< HEAD
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 32.0 : 20.0), // Reduced padding
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with back button
                        Row(
                          children: [
                            Container(
                              height: 36, // Slightly smaller
                              width: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                                onPressed: () => Get.back(),
                                padding: EdgeInsets.zero,
=======
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 30),

                  // Sign Up Button
                  SizedBox(
                    height: 50,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : GoldGradientButton(
                            onPressed: _signUp,
                            borderRadius: 8,
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),

<<<<<<< HEAD
                        const SizedBox(height: 16), // Reduced spacing

                        // Smaller logo
                        Container(
                          height: isTablet ? 70 : 60, // Reduced size
                          width: isTablet ? 70 : 60,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: goldGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: goldStart.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/new.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // Smaller title
                        GradientText(
                          'Create Account',
                          style: TextStyle(
                            fontSize: isTablet ? 24 : 20, // Reduced size
=======
                  // Role Selection
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                    ),
                    items: ['SALES_REP', 'RELIEVER'].map((String role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          role == 'SALES_REP'
                              ? 'Sales Representative'
                              : 'Reliever',
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Country and Region Fields
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCountry,
                          decoration: InputDecoration(
                            labelText: 'Country',
                            prefixIcon: const Icon(Icons.flag_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'Kenya', child: Text('Kenya')),
                            DropdownMenuItem(
                                value: 'Tanzania', child: Text('Tanzania')),
                            DropdownMenuItem(
                                value: 'Nigeria', child: Text('Nigeria')),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              _selectedCountry = value;
                              // Update country ID based on selection
                              switch (value) {
                                case 'Kenya':
                                  _selectedCountryId = 1;
                                  break;
                                case 'Tanzania':
                                  _selectedCountryId = 2;
                                  break;
                                case 'Nigeria':
                                  _selectedCountryId = 3;
                                  break;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _countryIdController,
                          decoration: InputDecoration(
                            labelText: 'Country ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          onChanged: (value) {
                            _selectedCountryId = int.tryParse(value) ?? 1;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _regionController,
                          decoration: InputDecoration(
                            labelText: 'Region',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _regionIdController,
                          decoration: InputDecoration(
                            labelText: 'Region ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Route Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _routeController,
                          decoration: InputDecoration(
                            labelText: 'Route',
                            prefixIcon: const Icon(Icons.route_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _routeIdController,
                          decoration: InputDecoration(
                            labelText: 'Route ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: GradientText(
                          'Sign In',
                          style: const TextStyle(
>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 2),

                        Text(
                          'Join us today and get started',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13, // Reduced size
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20), // Reduced spacing

                        // Compact form fields with reduced spacing
                        _buildCompactTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          prefixIcon: Icons.person_outline,
                          validator: _validateName,
                        ),

                        const SizedBox(height: 12), // Reduced spacing

                        _buildCompactTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: 12),

                        _buildCompactTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: 'Enter your phone number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),

                        const SizedBox(height: 12),

                        // Password fields in a row for smaller screens
                        _buildPasswordFields(),

                        const SizedBox(height: 12),

                        // Role and Department in a row
                        _buildRoleAndDepartmentRow(),

                        const SizedBox(height: 12),

                        // Location fields in a compact grid
                        _buildCompactLocationFields(),

                        const SizedBox(height: 20), // Reduced spacing

                        // Sign Up Button
                        _buildCompactSignUpButton(),

                        const SizedBox(height: 12), // Reduced spacing

                        // Sign in link
                        _buildSignInRow(),
                      ],
                    ),
                  ),
                ),
              ),

              // Small bottom spacing
              SizedBox(height: screenHeight * 0.01),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, // Smaller label
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4), // Reduced spacing
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText ?? false,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 14, // Slightly smaller text
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
              fontSize: 13, // Smaller hint text
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: Colors.grey.shade500,
              size: 16, // Smaller icon
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText!
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade500,
                      size: 16,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Slightly smaller radius
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldStart, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Reduced padding
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    if (isSmallScreen) {
      // Stack password fields vertically on very small screens
      return Column(
        children: [
          _buildCompactTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onTogglePassword: () => setState(() =>
                _obscurePassword = !_obscurePassword),
            validator: _validatePassword,
          ),
          const SizedBox(height: 12),
          _buildCompactTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscureConfirmPassword,
            onTogglePassword: () => setState(() =>
                _obscureConfirmPassword = !_obscureConfirmPassword),
            validator: _validateConfirmPassword,
          ),
        ],
      );
    } else {
      // Side by side on larger screens
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCompactTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscurePassword,
                onTogglePassword: () => setState(() =>
                    _obscurePassword = !_obscurePassword),
                validator: _validatePassword,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                onTogglePassword: () => setState(() =>
                    _obscureConfirmPassword = !_obscureConfirmPassword),
                validator: _validateConfirmPassword,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRoleAndDepartmentRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: _selectedRole == 'MANAGER' ? 1 : 2,
            child: _buildCompactDropdown(),
          ),
          if (_selectedRole == 'MANAGER') ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildCompactTextField(
                controller: _departmentController,
                label: 'Department',
                hint: 'Enter department',
                prefixIcon: Icons.business_outlined,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Department required'
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          isDense: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Select role',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.work_outline,
              color: Colors.grey.shade500,
              size: 16,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldStart, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: ['SALES_REP', 'MANAGER'].map((String role) {
            return DropdownMenuItem(
              value: role,
              child: Text(
                role == 'SALES_REP' ? 'Sales Rep' : 'Manager', // Shorter text
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedRole = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCompactLocationFields() {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCompactCountryDropdown(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactRegionDropdown(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          controller: _routeController,
          label: 'Route',
          hint: 'Route',
          prefixIcon: Icons.route_outlined,
          readOnly: true,
        ),
      ],
    );
  }

  Widget _buildCompactCountryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Country',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            prefixIcon: Icon(
              Icons.flag_outlined,
              color: Colors.grey.shade500,
              size: 14,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldStart, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          items: _countries.keys.map((String country) {
            return DropdownMenuItem(
              value: country,
              child: Text(
                country,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: _onCountryChanged,
        ),
      ],
    );
  }

  Widget _buildCompactRegionDropdown() {
    final regions = _selectedCountry != null
        ? _countries[_selectedCountry]!['regions'] as List<String>
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Region',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: regions.contains(_regionController.text)
              ? _regionController.text
              : regions.first,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Region',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: Colors.grey.shade500,
              size: 14,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: goldStart, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          items: regions.map((String region) {
            return DropdownMenuItem(
              value: region,
              child: Text(
                region,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _regionController.text = value;
                _routeController.text = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildCompactSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 46, // Slightly smaller button
      child: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: goldStart.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _signUp,
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12, // Smaller text
          ),
        ),
        GestureDetector(
          onTap: () => Get.back(),
          child: GradientText(
            'Sign In',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}