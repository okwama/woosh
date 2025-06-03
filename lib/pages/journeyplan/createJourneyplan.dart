import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:woosh/models/client_model.dart';
import 'package:woosh/models/journeyplan_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class CreateJourneyPlanPage extends StatefulWidget {
  final List<Client> clients;
  final Function(List<JourneyPlan>) onSuccess;

  const CreateJourneyPlanPage({
    super.key,
    required this.clients,
    required this.onSuccess,
  });

  @override
  State<CreateJourneyPlanPage> createState() => _CreateJourneyPlanPageState();
}

class _CreateJourneyPlanPageState extends State<CreateJourneyPlanPage> {
  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  late List<Client> filteredClients;
  final TextEditingController notesController = TextEditingController();
  int? selectedRouteId;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  List<Client> _allClients = [];

  @override
  void initState() {
    super.initState();
    _allClients = widget.clients;
    filteredClients = _allClients;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreClients();
      }
    }
  }

  Future<void> _loadMoreClients() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final routeId = ApiService.getCurrentUserRouteId();
      final response = await ApiService.fetchClients(
        routeId: routeId,
        page: _currentPage + 1,
        limit: 2000,
      );

      if (response.data.isEmpty) {
        setState(() {
          _hasMoreData = false;
        });
      } else {
        setState(() {
          _allClients.addAll(response.data);
          _currentPage++;
          _updateFilteredClients();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more clients: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _updateFilteredClients() {
    setState(() {
      filteredClients = _allClients.where((client) {
        return client.name.toLowerCase().contains(searchQuery) ||
            (client.address ?? '').toLowerCase().contains(searchQuery);
      }).toList();
    });
  }

  Future<void> createJourneyPlan(
    BuildContext context,
    int clientId,
    DateTime date, {
    String? notes,
    int? routeId,
    Function(List<JourneyPlan>)? onSuccess,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.createJourneyPlan(
        clientId,
        date,
        notes: notes,
        routeId: routeId,
      );

      // Refresh journey plans after creating a new one
      final journeyPlans = await ApiService.fetchJourneyPlans();

      if (onSuccess != null) {
        onSuccess(journeyPlans);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey plan created successfully')),
      );

      // Navigate back to the journey plans page
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create journey plan: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Create Journey Plan',
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top controls section - more compact
                Row(
                  children: [
                    // Date selector
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        const Color.fromARGB(255, 77, 77, 77)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MMM dd, yyyy')
                                        .format(selectedDate),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Route selector
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Route (Optional)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: ApiService.getRoutes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 36,
                                  child: Center(
                                      child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                );
                              }

                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.red));
                              }

                              final routes = snapshot.data ?? [];
                              return SizedBox(
                                height: 36, // Match the height of date selector
                                child: DropdownButtonFormField<int>(
                                  value: selectedRouteId,
                                  isDense: true,
                                  isExpanded: true,
                                  icon: Icon(Icons.arrow_drop_down, size: 18),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                          color: const Color.fromARGB(
                                              255, 74, 74, 74)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                          color: const Color.fromARGB(
                                              255, 74, 74, 74)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0.0, // Reduced vertical padding
                                      horizontal: 10.0,
                                    ),
                                  ),
                                  hint: const Text('Select route',
                                      style: TextStyle(fontSize: 13)),
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('No route',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                    ...routes
                                        .map((route) => DropdownMenuItem<int>(
                                              value: route['id'],
                                              child: Text(
                                                route['name'],
                                                style: const TextStyle(
                                                    fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRouteId = value;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  // In the TextField onChanged callback
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                      _updateFilteredClients();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search clients',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: const Color.fromARGB(255, 74, 74, 74)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: const Color.fromARGB(255, 74, 74, 74)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 10.0),
                  ),
                ),

                const SizedBox(height: 12),

                // Table header
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'CLIENT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          'ADDRESS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 30),
                    ],
                  ),
                ),

                // Client list in table format
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(255, 179, 179, 179)),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: widget.clients.isEmpty
                        ? const Center(
                            child: Text('No clients available',
                                style: TextStyle(fontSize: 13)))
                        : filteredClients.isEmpty
                            ? const Center(
                                child: Text('No matching clients found',
                                    style: TextStyle(fontSize: 13)))
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: filteredClients.length + (_hasMoreData ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == filteredClients.length) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final client = filteredClients[index];
                                  return InkWell(
                                    onTap: () {
                                      if (!_isLoading) {
                                        createJourneyPlan(
                                          context,
                                          client.id,
                                          selectedDate,
                                          notes: notesController.text.trim(),
                                          routeId: selectedRouteId,
                                          onSuccess: widget.onSuccess,
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: index ==
                                                    filteredClients.length - 1
                                                ? Colors.transparent
                                                : const Color.fromARGB(
                                                    255, 179, 179, 179),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              client.name,
                                              style:
                                                  const TextStyle(fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          //   Expanded(
                                          //     flex: 5,
                                          //     child: Text(
                                          //       client.address ?? '',
                                          //       style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          //       overflow: TextOverflow.ellipsis,
                                          //     ),
                                          //   ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.grey.shade400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Creating Journey Plan...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
