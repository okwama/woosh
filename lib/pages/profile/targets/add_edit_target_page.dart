import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/target_model.dart';
import 'package:woosh/services/target_service.dart';
import 'package:get_storage/get_storage.dart';

class AddEditTargetPage extends StatefulWidget {
  final Target? target;

  const AddEditTargetPage({super.key, this.target});

  @override
  State<AddEditTargetPage> createState() => _AddEditTargetPageState();
}

class _AddEditTargetPageState extends State<AddEditTargetPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  TargetType _selectedType = TargetType.SALES;
  bool _isCompleted = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.target != null) {
      _titleController.text = widget.target!.title;
      _descriptionController.text = widget.target!.description;
      _targetValueController.text = widget.target!.targetValue.toString();
      _startDate = widget.target!.startDate;
      _endDate = widget.target!.endDate;
      _selectedType = widget.target!.type;
      _isCompleted = widget.target!.isCompleted;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a title';
    }
    return null;
  }

  String? _validateTargetValue(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a target value';
    }
    if (int.tryParse(value) == null || int.parse(value) <= 0) {
      return 'Please enter a valid number greater than 0';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isStartDate
          ? DateTime.now().subtract(const Duration(days: 365))
          : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTarget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final userId = GetStorage().read<int>('userId') ?? 1;

    try {
      if (widget.target == null) {
        // Create new target
        final newTarget = Target(
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          userId: userId,
          targetValue: int.parse(_targetValueController.text),
          startDate: _startDate,
          endDate: _endDate,
        );

        await TargetService.createTarget(newTarget);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target created successfully')),
          );
          Navigator.pop(context, true); // Return success
        }
      } else {
        // Update existing target
        final updatedTarget = widget.target!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          targetValue: int.parse(_targetValueController.text),
          startDate: _startDate,
          endDate: _endDate,
        );

        await TargetService.updateTarget(updatedTarget);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target updated successfully')),
          );
          Navigator.pop(context, true); // Return success
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTarget() async {
    if (widget.target == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Target'),
        content: const Text('Are you sure you want to delete this target?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await TargetService.deleteTarget(widget.target!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target deleted successfully')),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting target: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.target != null;
    final dateFormatter = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Target' : 'New Target'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isSubmitting ? null : _deleteTarget,
              tooltip: 'Delete Target',
            ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTypeDropdown(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _targetValueController,
                            decoration: const InputDecoration(
                              labelText: 'Target Value',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateTargetValue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateFormatter.format(_startDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateFormatter.format(_endDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Mark as Completed'),
                      value: _isCompleted,
                      onChanged: (value) {
                        setState(() {
                          _isCompleted = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveTarget,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isEditing ? 'Update Target' : 'Create Target',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<TargetType>(
      value: _selectedType,
      decoration: const InputDecoration(
        labelText: 'Target Type',
        border: OutlineInputBorder(),
        helperText: 'Products sold targets are tracked every two weeks',
      ),
      items: [
        DropdownMenuItem(
          value: TargetType.SALES,
          child: Row(
            children: [
              Icon(Icons.inventory, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Products Sold'),
            ],
          ),
        ),
        // Other target types have been removed
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
          });
        }
      },
      validator: (value) =>
          value == null ? 'Please select a target type' : null,
    );
  }
}
