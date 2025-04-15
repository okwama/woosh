import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/models/outlet_model.dart';
import 'package:woosh/pages/journeyplan/journeyview.dart';
import 'package:woosh/services/api_service.dart';

class JourneyPlansPage extends StatefulWidget {
  const JourneyPlansPage({super.key});

  @override
  State<JourneyPlansPage> createState() => _JourneyPlansPageState();
}

class _JourneyPlansPageState extends State<JourneyPlansPage> {
  bool _isLoading = false;
  List<Outlet> _outlets = [];
  List<JourneyPlan> _journeyPlans = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Load both outlets and journey plans
      final outlets = await ApiService.fetchOutlets();
      final journeyPlans = await ApiService.fetchJourneyPlans();

      if (mounted) {
        setState(() {
          _outlets = outlets;
          _journeyPlans = journeyPlans;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    }
  }

  Future<void> _createJourneyPlan(int outletId, DateTime date,
      {String? notes}) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await ApiService.createJourneyPlan(
        outletId,
        date,
        notes: notes,
      );

      // Refresh journey plans after creating a new one
      final journeyPlans = await ApiService.fetchJourneyPlans();

      setState(() {
        _journeyPlans = journeyPlans;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey plan created successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create journey plan: ${e.toString()}')),
      );
    }
  }

  void _showOutletSelectionDialog() {
    DateTime selectedDate = DateTime.now();
    String searchQuery = '';
    List<Outlet> filteredOutlets = _outlets;
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Journey Plan'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Agenda (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any additional information',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 12.0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Search Outlet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                        filteredOutlets = _outlets.where((outlet) {
                          return outlet.name
                                  .toLowerCase()
                                  .contains(searchQuery) ||
                              outlet.address
                                  .toLowerCase()
                                  .contains(searchQuery);
                        }).toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or address',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 12.0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Outlet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _outlets.isEmpty
                        ? const Center(child: Text('No outlets available'))
                        : filteredOutlets.isEmpty
                            ? const Center(
                                child: Text('No matching outlets found'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredOutlets.length,
                                itemBuilder: (context, index) {
                                  final outlet = filteredOutlets[index];
                                  return ListTile(
                                    title: Text(outlet.name),
                                    subtitle: Text(outlet.address),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _createJourneyPlan(
                                        outlet.id,
                                        selectedDate,
                                        notes: notesController.text.trim(),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToJourneyView(JourneyPlan journeyPlan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyView(
          journeyPlan: journeyPlan,
          onCheckInSuccess: (updatedPlan) async {
            // Update the journey plan in the list
            setState(() {
              final index =
                  _journeyPlans.indexWhere((plan) => plan.id == updatedPlan.id);
              if (index != -1) {
                _journeyPlans[index] = updatedPlan;
              }
            });

            // Refresh the data to ensure everything is in sync
            await _loadData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Plans'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing journey plans...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _journeyPlans.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_location_alt_rounded,
                                size: 50,
                                color: Colors.grey,
                              ),
                              Text('No journey plans found'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          key: const PageStorageKey('journey_plans_list'),
                          itemCount: _journeyPlans.length,
                          itemBuilder: (context, index) {
                            final journeyPlan = _journeyPlans[index];
                            return Card(
                              key: ValueKey(
                                  'journey_plan_${journeyPlan.id}_$index'),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: InkWell(
                                onTap: () =>
                                    _navigateToJourneyView(journeyPlan),
                                borderRadius: BorderRadius.circular(8.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      // Left side - Date and Outlet info
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.store,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    journeyPlan.outlet.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('MMM dd, yyyy')
                                                        .format(
                                                            journeyPlan.date),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Right side - Status
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: journeyPlan.statusColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          journeyPlan.statusText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[400],
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOutletSelectionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
