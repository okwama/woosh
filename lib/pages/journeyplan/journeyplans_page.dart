import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/models/outlet_model.dart';
import 'package:whoosh/services/api_service.dart';

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load both outlets and journey plans
      final outlets = await ApiService.fetchOutlets();
      final journeyPlans = await ApiService.fetchJourneyPlans();
      
      setState(() {
        _outlets = outlets;
        _journeyPlans = journeyPlans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _createJourneyPlan(int outletId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await ApiService.createJourneyPlan(outletId);
      
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
        SnackBar(content: Text('Failed to create journey plan: ${e.toString()}')),
      );
    }
  }

  void _showOutletSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Outlet'),
        content: SizedBox(
          width: double.maxFinite,
          child: _outlets.isEmpty
              ? const Text('No outlets available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _outlets.length,
                  itemBuilder: (context, index) {
                    final outlet = _outlets[index];
                    return ListTile(
                      title: Text(outlet.name),
                      subtitle: Text(outlet.address),
                      onTap: () {
                        Navigator.pop(context);
                        _createJourneyPlan(outlet.id);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOutletSelectionDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildJourneyPlansView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyPlansView() {
    if (_journeyPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No Journey Plans',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the "+" button to create a new journey plan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _journeyPlans.length,
        itemBuilder: (context, index) {
          return _buildJourneyPlanCard(_journeyPlans[index]);
        },
      ),
    );
  }

  Widget _buildJourneyPlanCard(JourneyPlan journeyPlan) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.store,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    journeyPlan.outlet.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Dotted line separator
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: List.generate(
                30,
                (index) => Expanded(
                  child: Container(
                    color: index % 2 == 0 ? Colors.grey.shade300 : Colors.white,
                    height: 2,
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date and time
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Date',
                        dateFormatter.format(journeyPlan.date),
                        Icons.calendar_today,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Time',
                        timeFormatter.format(journeyPlan.time),
                        Icons.access_time,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Location
                _buildInfoItem(
                  'Location',
                  journeyPlan.outlet.address,
                  Icons.location_on,
                ),
                
                const SizedBox(height: 16),
                
                // Journey ID
                _buildInfoItem(
                  'Journey ID',
                  '#${journeyPlan.id}',
                  Icons.confirmation_number,
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16.0),
                bottomRight: Radius.circular(16.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to journey details or start journey
                    // You can implement this functionality later
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Start Journey'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}