import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/models/target_model.dart';
import 'package:whoosh/services/api_service.dart';
import 'package:get_storage/get_storage.dart';

class AddEditTargetPage extends StatefulWidget {
  final Target? target;

  const AddEditTargetPage({super.key, this.target});

  @override
  State<AddEditTargetPage> createState() => _AddEditTargetPageState();
}

class _AddEditTargetPageState extends State<AddEditTargetPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _currentValueController = TextEditingController();

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
      _currentValueController.text = widget.target!.currentValue.toString();
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
    _currentValueController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get user ID from storage
      final storage = GetStorage();
      final userId = storage.read('userId');

      if (userId == null) {
        throw Exception('User ID not found, please log in again');
      }

      final targetValue = int.parse(_targetValueController.text);
      final currentValue = int.parse(_currentValueController.text);

      // Create target object
      final target = Target(
        id: widget.target?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        type: _selectedType,
        userId: userId,
        targetValue: targetValue,
        currentValue: currentValue,
        startDate: _startDate,
        endDate: _endDate,
        isCompleted: _isCompleted,
      );

      // Save or update target
      if (widget.target == null) {
        await ApiService.createTarget(target);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target created successfully')),
          );
        }
      } else {
        await ApiService.updateTarget(target);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target updated successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteTarget() async {
    if (widget.target == null || widget.target!.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Target'),
        content: const Text(
            'Are you sure you want to delete this target? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiService.deleteTarget(widget.target!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target deleted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting target: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
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
                    DropdownButtonFormField<TargetType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Target Type',
                        border: OutlineInputBorder(),
                      ),
                      items: TargetType.values.map((type) {
                        String label;
                        switch (type) {
                          case TargetType.SALES:
                            label = 'Sales';
                            break;
                          case TargetType.VISITS:
                            label = 'Visits';
                            break;
                          case TargetType.PRODUCT_PLACEMENT:
                            label = 'Product Placement';
                            break;
                          case TargetType.CUSTOM:
                            label = 'Custom';
                            break;
                        }
                        return DropdownMenuItem(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a target value';
                              }
                              if (int.tryParse(value) == null ||
                                  int.parse(value) <= 0) {
                                return 'Please enter a valid number greater than 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _currentValueController,
                            decoration: const InputDecoration(
                              labelText: 'Current Progress',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current progress';
                              }
                              if (int.tryParse(value) == null ||
                                  int.parse(value) < 0) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
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
}
