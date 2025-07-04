import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/utils/error_handler.dart';
import 'package:woosh/utils/safe_error_handler.dart';
import 'package:woosh/utils/app_error_handler.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class ErrorTestPage extends StatefulWidget {
  const ErrorTestPage({super.key});

  @override
  State<ErrorTestPage> createState() => _ErrorTestPageState();
}

class _ErrorTestPageState extends State<ErrorTestPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Simulate different types of errors
  void _simulateError(String errorType) {
    dynamic error;

    switch (errorType) {
      case 'server_500':
        error = Exception(
            'HTTP 500: Internal Server Error - Something went wrong on our end');
        break;
      case 'server_501':
        error = Exception(
            'Error 501: Not Implemented - The server does not support this feature');
        break;
      case 'server_502':
        error = Exception(
            '502 Bad Gateway: The server received an invalid response');
        break;
      case 'server_503':
        error = Exception(
            'Service Unavailable (503): The server is temporarily overloaded');
        break;
      case 'client_401':
        error = Exception(
            '401 Unauthorized: Authentication credentials were missing or incorrect');
        break;
      case 'client_403':
        error = Exception(
            '403 Forbidden: You do not have permission to access this resource');
        break;
      case 'client_404':
        error = Exception(
            '404 Not Found: The requested resource could not be found');
        break;
      case 'client_429':
        error = Exception(
            '429 Too Many Requests: Rate limit exceeded, please slow down');
        break;
      case 'network_socket':
        error = Exception(
            'SocketException: Failed to connect to the server (OS Error: Connection refused)');
        break;
      case 'network_timeout':
        error =
            Exception('TimeoutException after 0:00:30.000000: Request timeout');
        break;
      case 'network_xmlhttp':
        error = Exception('XMLHttpRequest error: Network request failed');
        break;
      case 'validation':
        error = Exception(
            'ValidationException: The email field is required and must be valid');
        break;
      case 'generic':
        error = Exception(
            'Something went terribly wrong with stack traces and technical details that users should never see');
        break;
      default:
        error = Exception('Unknown error type');
    }

    // Test the error using our safe error handler
    AppErrorHandler.showError(context, error);
  }

  void _simulateGetError(String errorType) {
    dynamic error;

    switch (errorType) {
      case 'server_500':
        error = Exception(
            'HTTP 500: Internal Server Error - Raw technical details here');
        break;
      case 'network':
        error = Exception(
            'SocketException: Connection failed (OS Error: No route to host)');
        break;
      default:
        error = Exception('Generic error with technical details');
    }

    // Test with Get.snackbar through our safe handler
    AppErrorHandler.showGetError(error, onRetry: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retry button was pressed!')),
      );
    });
  }

  void _simulateDialog(String errorType) {
    dynamic error;

    switch (errorType) {
      case 'server_500':
        error = Exception(
            'HTTP 500: Internal Server Error with stack trace and technical details');
        break;
      case 'network':
        error = Exception(
            'SocketException: Failed to connect (OS Error: Connection refused, errno = 111)');
        break;
      default:
        error = Exception(
            'Raw error with technical details that should be filtered');
    }

    // Test error dialog
    AppErrorHandler.showErrorDialog(context, error, onRetry: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dialog retry was pressed!')),
      );
    });
  }

  void _testSuccessMessage() {
    AppErrorHandler.showSuccess(
        context, 'This is a success message - should show as-is');
  }

  void _testGlobalErrorHandler() {
    final testErrors = [
      Exception('HTTP 500: Internal Server Error'),
      Exception('SocketException: Connection failed'),
      Exception('401 Unauthorized'),
      Exception('TimeoutException'),
    ];

    for (final error in testErrors) {
      GlobalErrorHandler.handleApiError(error);
      // Small delay between errors to see them individually
      Future.delayed(
          Duration(milliseconds: 500 * (testErrors.indexOf(error) + 1)));
    }
  }

  void _testRawErrorComparison() {
    // Show what a RAW error would look like (for comparison)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?? RAW Error Example (DON\'T DO THIS)'),
        content: const Text(
          'HTTP 500: Internal Server Error\n'
          'at Object.throw_ [as throw] (http://localhost:8080/dart_sdk.js:5348:11)\n'
          'at Object.assertFailed (http://localhost:8080/dart_sdk.js:5270:15)\n'
          'at dart:core/errors.dart:229:7\n\n'
          'This is what users would see with raw errors!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Now show the same error through our safe handler
              AppErrorHandler.showError(
                context,
                Exception(
                    'HTTP 500: Internal Server Error with technical details'),
              );
            },
            child: const Text('Show Safe Version'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const GradientAppBar(
        title: 'Error Handling Test',
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Error Handling Test Suite',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test that raw errors are never shown to users',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Server Errors Section
            _buildTestSection(
              'Server Errors (5xx)',
              'These should show: "Our servers are temporarily unavailable"',
              Icons.dns,
              Colors.red,
              [
                _buildTestButton(
                    'Test 500 Error', () => _simulateError('server_500')),
                _buildTestButton(
                    'Test 501 Error', () => _simulateError('server_501')),
                _buildTestButton(
                    'Test 502 Error', () => _simulateError('server_502')),
                _buildTestButton(
                    'Test 503 Error', () => _simulateError('server_503')),
              ],
            ),

            const SizedBox(height: 16),

            // Client Errors Section
            _buildTestSection(
              'Client Errors (4xx)',
              'These should show appropriate user-friendly messages',
              Icons.person_off,
              Colors.orange,
              [
                _buildTestButton('Test 401 Unauthorized',
                    () => _simulateError('client_401')),
                _buildTestButton(
                    'Test 403 Forbidden', () => _simulateError('client_403')),
                _buildTestButton(
                    'Test 404 Not Found', () => _simulateError('client_404')),
                _buildTestButton(
                    'Test 429 Rate Limit', () => _simulateError('client_429')),
              ],
            ),

            const SizedBox(height: 16),

            // Network Errors Section
            _buildTestSection(
              'Network Errors',
              'These should show: "Please check your internet connection"',
              Icons.wifi_off,
              Colors.blue,
              [
                _buildTestButton('Test Socket Exception',
                    () => _simulateError('network_socket')),
                _buildTestButton(
                    'Test Timeout', () => _simulateError('network_timeout')),
                _buildTestButton('Test XMLHttp Error',
                    () => _simulateError('network_xmlhttp')),
              ],
            ),

            const SizedBox(height: 16),

            // Other Error Types
            _buildTestSection(
              'Other Error Types',
              'These should show generic user-friendly messages',
              Icons.error,
              Colors.purple,
              [
                _buildTestButton('Test Validation Error',
                    () => _simulateError('validation')),
                _buildTestButton(
                    'Test Generic Error', () => _simulateError('generic')),
              ],
            ),

            const SizedBox(height: 16),

            // Different Display Methods
            _buildTestSection(
              'Different Display Methods',
              'Test different ways of showing errors',
              Icons.display_settings,
              Colors.green,
              [
                _buildTestButton(
                    'SnackBar Error', () => _simulateError('server_500')),
                _buildTestButton('Get.snackbar Error',
                    () => _simulateGetError('server_500')),
                _buildTestButton(
                    'Dialog Error', () => _simulateDialog('server_500')),
                _buildTestButton('Success Message', _testSuccessMessage),
              ],
            ),

            const SizedBox(height: 16),

            // Global Tests
            _buildTestSection(
              'Global Error Handler',
              'Test the global error handling system',
              Icons.public,
              Colors.teal,
              [
                _buildTestButton(
                    'Test Multiple Errors', _testGlobalErrorHandler),
                _buildTestButton(
                    'Raw vs Safe Comparison', _testRawErrorComparison),
              ],
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Test Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Tap any error test button\n'
                      '2. Verify you see a user-friendly message\n'
                      '3. Verify you DO NOT see raw error codes or technical details\n'
                      '4. Check that retry buttons work when available\n'
                      '5. Test different error types to ensure consistent behavior',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(
    String title,
    String description,
    IconData icon,
    Color color,
    List<Widget> buttons,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: buttons,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
