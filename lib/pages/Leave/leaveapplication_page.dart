import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/pages/Leave/leave_requests_page.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:intl/date_symbol_data_local.dart';

<<<<<<< HEAD
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';
=======
import 'package:glamour_queen/utils/app_theme.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';

>>>>>>> bbae5e015fc753bdada7d71b1e6421572860e4a2
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

  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime _endDate =
      DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));

  final List<String> _leaveTypes = ['Annual', 'Sick', 'Paternal'];

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

    if ((_selectedLeaveType == 'Sick' || _selectedLeaveType == 'Paternal') &&
        !_isFileAttached) {
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

      await ApiService.submitLeaveApplication(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      value: _selectedLeaveType,
                      decoration: const InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _leaveTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      validator: _validateLeaveType,
                      onChanged: (value) {
                        setState(() {
                          _selectedLeaveType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _startDateController,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) => value?.isEmpty == true
                          ? 'Please select start date'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _endDateController,
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) => value?.isEmpty == true
                          ? 'Please select end date'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
                      validator: _validateReason,
                    ),
                    const SizedBox(height: 8),
                    if (_selectedLeaveType == 'Sick' ||
                        _selectedLeaveType == 'Paternal') ...[
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                            'Attach Document (Required for ${_selectedLeaveType ?? ""} Leave)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (_isFileAttached)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'File attached: $_fileName',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    GoldGradientButton(
                      onPressed: _submitLeaveApplication,
                      child: const Text('Submit Application'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
