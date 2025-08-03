import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/leave_model.dart';
import 'package:woosh/services/leave/leave_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
import 'package:woosh/pages/Leave/leave_requests_page.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:intl/date_symbol_data_local.dart';

class LeaveApplicationPage extends StatefulWidget {
  const LeaveApplicationPage({super.key});

  @override
  _LeaveApplicationPageState createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedLeaveType;
  dynamic _attachedFile; // Changed to dynamic to handle both File and bytes
  String? _fileName;
  bool _isLoading = false;
  String? _error;
  bool _isFileAttached = false;
  List<Map<String, dynamic>> _leaveTypes = [];
  bool _isLoadingLeaveTypes = true;

  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime _endDate =
      DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));

  @override
  void initState() {
    super.initState();
    _loadLeaveTypes();
  }

  Future<void> _loadLeaveTypes() async {
    try {
      final leaveTypes = await LeaveService.getLeaveTypes();
      setState(() {
        _leaveTypes = leaveTypes;
        _isLoadingLeaveTypes = false;
      });
    } catch (e) {
      print('Failed to load leave types: $e');
      // Fallback to default leave types
      setState(() {
        _leaveTypes = [
          {'name': 'Annual', 'id': 1},
          {'name': 'Sick', 'id': 2},
          {'name': 'Maternity', 'id': 3},
          {'name': 'Paternity', 'id': 4},
        ];
        _isLoadingLeaveTypes = false;
      });
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isStartDate) {
          _startDateController.text = formattedDate;
          _startDate = DateUtils.dateOnly(picked);
        } else {
          _endDateController.text = formattedDate;
          _endDate = DateUtils.dateOnly(picked);
        }
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
        withData: kIsWeb, // Get file bytes for web
      );

      if (result != null) {
        setState(() {
          _fileName = result.files.single.name;

          if (kIsWeb) {
            // On web, store the file bytes
            _attachedFile = result.files.single.bytes;
          } else {
            // On mobile, store the file path
            _attachedFile = File(result.files.single.path!);
          }

          _isFileAttached = true;
        });

        print('File picked: $_fileName');
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking file: $e';
      });
      print('Error picking file: $e');
    }
  }

  String? _validateLeaveType(String? value) {
    return value == null || value.isEmpty ? 'Please select a leave type' : null;
  }

  String? _validateReason(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please provide a reason for your leave';
    }
    if (value.length < 10) {
      return 'Please provide a more detailed reason';
    }
    return null;
  }

  bool _validateDates() {
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date cannot be before start date');
      return false;
    }
    final yesterday =
        DateUtils.addDaysToDate(DateUtils.dateOnly(DateTime.now()), -1);
    if (_startDate.isBefore(yesterday)) {
      setState(() => _error =
          'The start date is too old. Please pick yesterday or a future date.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate() || !_validateDates()) return;

    // Check if leave type requires attachment
    final selectedType = _leaveTypes.firstWhere(
      (type) => type['name'] == _selectedLeaveType,
      orElse: () => {'name': '', 'requiresAttachment': false},
    );

    final requiresAttachment = selectedType['requiresAttachment'] ?? false;

    if (requiresAttachment && !_isFileAttached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please attach a document for ${_selectedLeaveType?.toLowerCase()} leave'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Submitting leave application from UI:');
      print('Leave Type: $_selectedLeaveType');
      print('Start Date: ${_startDateController.text}');
      print('End Date: ${_endDateController.text}');
      print('Reason: ${_reasonController.text}');
      print('File attached: ${_isFileAttached ? "Yes" : "No"}');
      print('File name: $_fileName');

      await LeaveService.submitLeaveApplication(
        leaveType: _selectedLeaveType!,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        reason: _reasonController.text,
        attachmentFile: _isFileAttached ? _attachedFile : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error during leave submission: $e');
      setState(() {
        _error = 'Failed to submit leave application: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Leave Application',
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaveRequestsPage(),
                ),
              );
            },
            tooltip: 'View Leave Requests',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Leave Type Selection
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Leave Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedLeaveType,
                              decoration: InputDecoration(
                                labelText: _isLoadingLeaveTypes
                                    ? 'Loading leave types...'
                                    : 'Select Leave Type',
                                labelStyle:
                                    TextStyle(color: Colors.grey.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: _isLoadingLeaveTypes
                                  ? []
                                  : _leaveTypes.map((type) {
                                      return DropdownMenuItem<String>(
                                        value: type['name'] as String,
                                        child: Text(
                                          type['name'] as String,
                                          style: TextStyle(
                                              color: Colors.grey.shade800),
                                        ),
                                      );
                                    }).toList(),
                              validator: _validateLeaveType,
                              onChanged: _isLoadingLeaveTypes
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedLeaveType = value;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Date Selection
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Leave Period',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _startDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Start Date',
                                      labelStyle: TextStyle(
                                          color: Colors.grey.shade600),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () =>
                                            _selectDate(context, true),
                                      ),
                                    ),
                                    readOnly: true,
                                    style:
                                        TextStyle(color: Colors.grey.shade800),
                                    validator: (value) => value?.isEmpty == true
                                        ? 'Please select start date'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _endDateController,
                                    decoration: InputDecoration(
                                      labelText: 'End Date',
                                      labelStyle: TextStyle(
                                          color: Colors.grey.shade600),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () =>
                                            _selectDate(context, false),
                                      ),
                                    ),
                                    readOnly: true,
                                    style:
                                        TextStyle(color: Colors.grey.shade800),
                                    validator: (value) => value?.isEmpty == true
                                        ? 'Please select end date'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reason
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reason for Leave',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reasonController,
                              decoration: InputDecoration(
                                labelText: 'Please provide a detailed reason',
                                labelStyle:
                                    TextStyle(color: Colors.grey.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: 4,
                              style: TextStyle(color: Colors.grey.shade800),
                              validator: _validateReason,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // File Attachment
                      if (_selectedLeaveType == 'Sick' ||
                          _selectedLeaveType == 'Paternity') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Document Attachment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please attach supporting documents (medical certificate, etc.)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_isFileAttached)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _fileName ?? 'File attached',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: Colors.green.shade600,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _attachedFile = null;
                                            _fileName = null;
                                            _isFileAttached = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Attach Document'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade100,
                                    foregroundColor: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _submitLeaveApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Submit Leave Application',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
