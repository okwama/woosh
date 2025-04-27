import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:woosh/services/api_service.dart';

class CheckInHistoryPage extends StatefulWidget {
  const CheckInHistoryPage({super.key});

  @override
  State<CheckInHistoryPage> createState() => _CheckInHistoryPageState();
}

class _CheckInHistoryPageState extends State<CheckInHistoryPage> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _history = [];
  final DateFormat _dateFormat = DateFormat('MMM d, y');
  final DateFormat _timeFormat = DateFormat('h:mm a');

  // Pagination and filtering state
  int _currentPage = 1;
  bool _hasMore = true;
  String _currentFilter = 'all';
  final ScrollController _scrollController = ScrollController();

  // Add these variables to the state class
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    await _loadHistory(page: _currentPage + 1);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadHistory({bool isRefresh = false, int? page}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _history = [];
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final queryParams = {
        'page': (page ?? _currentPage).toString(),
        'limit': '10',
      };

      // Add filter parameters based on selected filter
      if (_currentFilter != 'all') {
        if (_currentFilter == 'custom' &&
            _startDate != null &&
            _endDate != null) {
          queryParams['startDate'] = _startDate!.toIso8601String();
          queryParams['endDate'] = _endDate!.toIso8601String();
        } else {
          queryParams['filter'] = _currentFilter;
        }
      }

      final uri = Uri.parse('${ApiService.baseUrl}/checkin/history')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(
        uri,
        headers: await _getAuthHeaders(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newHistory = List<Map<String, dynamic>>.from(data['history']);

        setState(() {
          if (isRefresh || page == 1) {
            _history = newHistory;
          } else {
            _history.addAll(newHistory);
          }
          _currentPage = data['meta']['page'];
          _hasMore = data['meta']['hasMore'];
          _isLoading = false;
        });
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load history');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final box = GetStorage();
    final token = box.read<String>('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _formatDuration(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null || checkOut == null) return 'In Progress';
    final duration = checkOut.difference(checkIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHistory(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Time', 'all'),
                const SizedBox(width: 8),
                _filterChip('Today', 'today'),
                const SizedBox(width: 8),
                _filterChip('This Week', 'week'),
                const SizedBox(width: 8),
                _filterChip('This Month', 'month'),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(
                    'Custom Range',
                    style: TextStyle(
                      color: _currentFilter == 'custom'
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _currentFilter == 'custom'
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade200,
                  onPressed: () => _showDateRangePicker(),
                ),
              ],
            ),
          ),
          if (_currentFilter == 'custom' &&
              _startDate != null &&
              _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _currentFilter = 'all';
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadHistory(isRefresh: true);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
      ),
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _currentFilter = value);
          _loadHistory(isRefresh: true);
        }
      },
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentFilter = 'custom';
      });
      _loadHistory(isRefresh: true);
    }
  }

  Widget _buildBody() {
    if (_isLoading && _history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadHistory(isRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(
        child: Text('No check-in history found'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _history.length + (_hasMore ? 1 : 0),
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          if (index == _history.length) {
            return _buildLoadingIndicator();
          }

          final record = _history[index];
          final checkInTime = record['checkInAt'] != null
              ? DateTime.parse(record['checkInAt'])
              : null;
          final checkOutTime = record['checkOutAt'] != null
              ? DateTime.parse(record['checkOutAt'])
              : null;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dateFormat.format(DateTime.parse(record['date'])),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: checkOutTime != null
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          checkOutTime != null ? 'Completed' : 'In Progress',
                          style: TextStyle(
                            color: checkOutTime != null
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.store, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record['client']['name'] ?? 'Unknown Client',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Check-in',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              checkInTime != null
                                  ? _timeFormat.format(checkInTime)
                                  : '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Check-out',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              checkOutTime != null
                                  ? _timeFormat.format(checkOutTime)
                                  : '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duration',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatDuration(checkInTime, checkOutTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (record['notes'] != null &&
                      record['notes'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      record['notes'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (record['imageUrl'] != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        record['imageUrl'],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.error_outline,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}
