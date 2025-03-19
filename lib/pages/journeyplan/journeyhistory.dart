import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whoosh/models/journeyplan_model.dart';
import 'package:whoosh/services/api_service.dart';

class JourneyHistoryPage extends StatefulWidget {
  const JourneyHistoryPage({Key? key}) : super(key: key);

  @override
  State<JourneyHistoryPage> createState() => _JourneyHistoryPageState();
}

class _JourneyHistoryPageState extends State<JourneyHistoryPage> {
  bool _isLoading = true;
  List<JourneyPlan> _journeyPlans = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJourneyPlans();
  }

  Future<void> _loadJourneyPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final journeyPlans = await ApiService.fetchJourneyPlans();
      setState(() {
        _journeyPlans = journeyPlans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load journey plans: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey History'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJourneyPlans,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
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
                onPressed: _loadJourneyPlans,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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
              'You haven\'t created any journey plans yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJourneyPlans,
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