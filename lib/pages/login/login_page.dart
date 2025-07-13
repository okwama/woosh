import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/services/session_service.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/token_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthController _authController = Get.find<AuthController>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  DateTime? _lastLoginAttempt;

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
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

  void _showMessage(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    // Validate inputs
    if (_phoneNumberController.text.trim().isEmpty) {
      _showMessage('Please enter your phone number', true);
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showMessage('Please enter your password', true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Try login with retry mechanism
    await _loginWithRetry();
  }

  Future<void> _loginWithRetry() async {
    const int maxRetries = 2;
    const Duration initialDelay = Duration(seconds: 1);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Show appropriate message based on attempt
        if (attempt == 1) {
          _showMessage('Logging in...', false);
        } else {
          _showMessage(
              'Retrying login... (Attempt $attempt/$maxRetries)', false);
        }

        final result = await _apiService.login(
          _phoneNumberController.text.trim(),
          _passwordController.text,
        );

        if (result['success']) {
          // Pass the result to auth controller
          await _authController.handleLoginResult(result);

          // Get user role from the result
          final salesRep = result['salesRep'];
          final userRole = salesRep?['role'] ?? '';

          // Store user ID for later use
          if (salesRep?['id'] != null) {
            GetStorage().write('userId', salesRep!['id'].toString());
          }

          // Show success message
          _showMessage('Login successful!', false);

          // Redirect based on role after a brief delay
          await Future.delayed(const Duration(milliseconds: 800));

          if (userRole.toString().toLowerCase() == 'manager') {
            Get.offAllNamed('/manager-home');
          } else {
            Get.offAllNamed('/home');
          }
          return; // Success, exit retry loop
        } else {
          // Login failed but no exception thrown - show error immediately
          _showMessage(result['message'] ?? 'Login failed', true);
          return; // Don't retry for authentication failures
        }
      } catch (e) {
        String errorMessage = 'Login failed';
        bool shouldRetry = false;

        // Handle specific error types
        if (e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('connection')) {
          errorMessage = 'No internet connection. Please check your network.';
          shouldRetry = true;
        } else if (e.toString().toLowerCase().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
          shouldRetry = true;
        } else if (e.toString().toLowerCase().contains('401') ||
            e.toString().toLowerCase().contains('unauthorized')) {
          errorMessage = 'Invalid phone number or password.';
          // Don't retry for authentication errors
        } else if (e.toString().toLowerCase().contains('500') ||
            e.toString().toLowerCase().contains('server')) {
          errorMessage = 'Server temporarily unavailable.';
          shouldRetry = true;
        } else if (e.toString().toLowerCase().contains('429') ||
            e.toString().toLowerCase().contains('too many requests')) {
          errorMessage = 'Too many login attempts. Please wait a moment.';
          // Don't retry for rate limiting
        } else {
          // Unknown error, retry once
          errorMessage = 'Connection error. Please try again.';
          shouldRetry = true;
        }

        // If this is the last attempt or we shouldn't retry
        if (attempt == maxRetries || !shouldRetry) {
          // Show final error message only after all retries are exhausted
          _showMessage(errorMessage, true);
          break;
        }

        // Wait before retry with exponential backoff (no error message during retry)
        final delay = Duration(seconds: initialDelay.inSeconds * attempt);
        await Future.delayed(delay);

        // Check if user is still on the login page
        if (!mounted || !_isLoading) {
          break;
        }
      }
    }

    // Reset loading state
    if (mounted) {
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
    final horizontalPadding = isTablet ? screenWidth * 0.25 : 20.0;
    final maxFormWidth = isTablet ? 400.0 : double.infinity;

    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reduced top spacer
                      SizedBox(height: screenHeight * 0.03),

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
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isTablet ? 40.0 : 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Enlarged logo with enhanced styling
                              Container(
                                height: isTablet ? 120 : 100,
                                width: isTablet ? 120 : 100,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: goldGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: goldStart.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(2.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Image.asset(
                                    'assets/new.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              // App name image
                              Container(
                                height: isTablet ? 50 : 42,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Image.asset(
                                  'assets/name.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: isTablet ? 28 : 20),

                              // Compact form
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Phone Number Field
                                    _buildModernTextField(
                                      controller: _phoneNumberController,
                                      label: 'Phone Number',
                                      hint: 'Enter your phone number',
                                      prefixIcon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: _validatePhoneNumber,
                                    ),

                                    const SizedBox(height: 16),

                                    // Password Field
                                    _buildModernTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Enter your password',
                                      prefixIcon: Icons.lock_outline,
                                      isPassword: true,
                                      validator: _validatePassword,
                                    ),

                                    const SizedBox(height: 24),

                                    // Login Button
                                    _buildModernLoginButton(),

                                    const SizedBox(height: 16),

                                    // Sign up row
                                    _buildSignUpRow(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Reduced bottom spacer
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: Colors.grey.shade500,
              size: 18,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: goldStart, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildModernLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Signing In...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: goldStart.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _handleLogin,
                  borderRadius: BorderRadius.circular(14),
                  child: const Center(
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
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

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: () => Get.toNamed('/sign-up'),
          child: GradientText(
            'Sign Up',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
