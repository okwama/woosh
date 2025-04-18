import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:woosh/controllers/auth_controller.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_widgets.dart';

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
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.login(
        _phoneNumberController.text.trim(),
        _passwordController.text,
      );

      if (result['success']) {
        _authController.isLoggedIn.value = true;

        // Get user role from the result
        final user = result['user'];
        final userRole = user?['role'] ?? '';

        // Redirect based on role
        if (userRole.toString().toLowerCase() == 'manager') {
          Get.offAllNamed('/manager-home');
        } else {
          Get.offAllNamed('/home');
        }

        _showToast('Login successful', false);
      } else {
        _showToast(result['message'] ?? 'Login failed', true);
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
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    height: 120,
                    width: 120,
                    margin: const EdgeInsets.only(bottom: 40),
                    decoration: GradientDecoration.goldCircular(),
                    padding: const EdgeInsets.all(2.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(15),
                      child: Image.asset('assets/images/svg.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                ),

                // Welcome Text
                GradientText(
                  'Woosh',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Field
                      _buildPhoneNumberField(),

                      const SizedBox(height: 20),

                      // Password Field
                      _buildPasswordField(),

                      const SizedBox(height: 12),

                      // Forgot Password
                      _buildForgotPasswordButton(),

                      const SizedBox(height: 24),

                      // Login Button
                      _buildLoginButton(),

                      const SizedBox(height: 24),

                      // Don't have an account
                      _buildSignUpRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildPoweredByFooter(context),
    );
  }

  Widget _buildPhoneNumberField() {
    return TextFormField(
      controller: _phoneNumberController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter your phone number',
        prefixIcon: const Icon(Icons.phone_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      validator: _validatePhoneNumber,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Get.toNamed('/forgot-password');
        },
        child: GradientText(
          'Forgot Password?',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: _isLoading
          ? Center(
              child: Transform.scale(
                scale: 0.9, // Adjust the scale to reduce the size
                child:
                    const GradientCircularProgressIndicator(), // Assuming this is your custom widget
              ),
            )
          : GoldGradientButton(
              onPressed: _login,
              borderRadius: 8,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Don\'t have an account? ',
          style: TextStyle(
            color: Color(0xFF666666),
          ),
        ),
        GestureDetector(
          onTap: () {
            Get.toNamed('/register');
          },
          child: GradientText(
            'Sign Up',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoweredByFooter(BuildContext context) {
    final year = DateTime.now().year;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      color: appBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Powered by ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Colors.orange,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Cit Logistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.verified,
                size: 16,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.copyright,
                size: 10,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 2),
              Text(
                '$year Management System',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
