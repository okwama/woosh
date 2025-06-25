import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:glamour_queen/models/client_model.dart';
import 'package:glamour_queen/models/journeyplan_model.dart';
import 'package:glamour_queen/services/api_service.dart';
import 'package:glamour_queen/widgets/gradient_app_bar.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

// Simple class to represent a match
class _Match {
  final int start;
  final int end;
  _Match(this.start, this.end);
}

// Add this class to store client with relevance score
class _ScoredClient {
  final Client client;
  final double score;
  _ScoredClient(this.client, this.score);
}

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
  final TextEditingController searchController = TextEditingController();
  int? selectedRouteId;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  List<Client> _allClients = [];
  Timer? _debounce;
  bool _searchByName = true;
  bool _searchByAddress = true;
  Map<String, List<Client>> _searchCache = {};
  bool _isInitialLoad = true;
  bool _isCreatingJourneyPlan = false;

  @override
  void initState() {
    super.initState();
    _debugAuthStatus();
    _initializeClients();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    notesController.dispose();
    searchController.dispose();
    _debounce?.cancel();
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

  Future<void> _initializeClients() async {
    if (_isInitialLoad) {
      setState(() {
        _isLoading = true;
      });

      try {
        // First, use the passed clients as initial data for quick display
        _allClients = widget.clients;
        filteredClients = _allClients;

        // Only fetch from API if we don't have enough clients or if explicitly needed
        if (_allClients.length < 10) {
          print(
              '?? Fetching all clients (no route filtering) - only ${_allClients.length} clients available');

          final response = await ApiService.fetchClients(
            routeId: null, // Don't filter by route - get all clients
            page: 1,
            limit: 2000,
          );

          print('? Fetched ${response.data.length} clients from API');

          setState(() {
            _allClients = response.data;
            filteredClients = _allClients;
            _currentPage = 1;
            _hasMoreData = response.page < response.totalPages;
          });

          // Preload more clients in the background if there are more pages
          if (_hasMoreData) {
            _loadMoreClients();
          }
        } else {
          print(
              '? Using ${_allClients.length} preloaded clients - no need to fetch from API');
          setState(() {
            _currentPage = 1;
            _hasMoreData = false; // Assume we have all clients if we have many
          });
        }
      } catch (e) {
        print('? Error loading clients: $e');

        // If API fails, keep the passed clients as fallback
        if (_allClients.isEmpty && widget.clients.isNotEmpty) {
          setState(() {
            _allClients = widget.clients;
            filteredClients = _allClients;
          });
          print('?? Using fallback clients: ${widget.clients.length} clients');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error loading clients: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _loadMoreClients() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      print(
          '?? Loading more clients (no route filtering) - page ${_currentPage + 1}');

      final response = await ApiService.fetchClients(
        routeId: null, // Don't filter by route - get all clients
        page: _currentPage + 1,
        limit: 2000,
      );

      print('? Fetched ${response.data.length} more clients from API');

      if (response.data.isEmpty) {
        setState(() {
          _hasMoreData = false;
        });
      } else {
        setState(() {
          // Use a Set to prevent duplicates
          final existingIds = _allClients.map((c) => c.id).toSet();
          final newClients =
              response.data.where((c) => !existingIds.contains(c.id)).toList();
          _allClients.addAll(newClients);
          _currentPage++;
          _hasMoreData = response.page < response.totalPages;
          _updateFilteredClients();
        });
      }
    } catch (e) {
      print('? Error loading more clients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error loading more clients: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshClients() async {
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _searchCache.clear();
    });

    try {
      print('?? Refreshing all clients (no route filtering)');

      final response = await ApiService.fetchClients(
        routeId: null, // Don't filter by route - get all clients
        page: 1,
        limit: 2000,
      );

      print('? Refreshed ${response.data.length} clients from API');

      setState(() {
        _allClients = response.data;
        _hasMoreData = response.page < response.totalPages;
        _updateFilteredClients();
      });
    } catch (e) {
      print('? Error refreshing clients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error refreshing clients: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchQuery = query.toLowerCase();
        _updateFilteredClients();
        // Reset scroll position to top when search query changes
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[-\s_.,;:/\\]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<_ScoredClient> _matchAndScoreClients(
      List<Client> clients, List<String> patternWords) {
    final scoredClients = <_ScoredClient>[];
    final searchQuery = patternWords.join(' ').trim().toLowerCase();

    for (final client in clients) {
      final name = client.name.trim().toLowerCase();
      final address = client.address?.trim().toLowerCase() ?? '';

      // Skip empty searches
      if (searchQuery.isEmpty) {
        scoredClients.add(_ScoredClient(client, 0.0));
        continue;
      }

      double score = 0.0;

      // Exact full string match
      if (name == searchQuery || address == searchQuery) {
        score = 1000.0;
      }
      // Contains exact search query as a substring
      else if (name.contains(searchQuery) || address.contains(searchQuery)) {
        score = 800.0;
        // Boost score if it matches at word boundary
        if (name.split(' ').any((word) => word == searchQuery) ||
            address.split(' ').any((word) => word == searchQuery)) {
          score = 900.0;
        }
        // Boost score if it matches at start
        if (name.startsWith(searchQuery) || address.startsWith(searchQuery)) {
          score += 50.0;
        }
      }
      // Partial word match
      else {
        final searchWords = searchQuery.split(' ');
        final nameWords = name.split(' ');
        final addressWords = address.split(' ');

        int matchedWords = 0;
        for (final searchWord in searchWords) {
          if (nameWords.any((word) => word.contains(searchWord)) ||
              addressWords.any((word) => word.contains(searchWord))) {
            matchedWords++;
          }
        }

        if (matchedWords > 0) {
          score = 500.0 * (matchedWords / searchWords.length);
        }
      }

      if (score > 0) {
        scoredClients.add(_ScoredClient(client, score));
      }
    }

    scoredClients.sort((a, b) => b.score.compareTo(a.score));
    return scoredClients;
  }

  void _updateFilteredClients() {
    if (searchQuery.isEmpty) {
      setState(() {
        filteredClients = _allClients;
        // Reset scroll position when clearing search
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      return;
    }

    if (_searchCache.containsKey(searchQuery)) {
      setState(() {
        filteredClients = _searchCache[searchQuery]!;
        // Reset scroll position when using cached results
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      return;
    }

    final patternWords = _normalizeText(searchQuery).split(' ');
    final scoredClients = _matchAndScoreClients(_allClients, patternWords);

    setState(() {
      filteredClients = scoredClients.map((sc) => sc.client).toList();
      _searchCache[searchQuery] = filteredClients;
    });
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final normalizedText = _normalizeText(text);
    final normalizedQuery = _normalizeText(query);
    final queryWords = normalizedQuery.split(' ');
    final matches = <_Match>[];

    for (final word in queryWords) {
      if (word.isEmpty) continue;

      int startIndex = 0;
      while (true) {
        final index = normalizedText.indexOf(word, startIndex);
        if (index == -1) break;

        int originalIndex = _findOriginalPosition(text, normalizedText, index);
        int originalEnd =
            _findOriginalPosition(text, normalizedText, index + word.length);
        matches.add(_Match(originalIndex, originalEnd));

        startIndex = index + 1;
      }
    }

    if (matches.isEmpty) return Text(text);

    matches.sort((a, b) => a.start.compareTo(b.start));

    final mergedMatches = <_Match>[];
    _Match? currentMatch;

    for (final match in matches) {
      if (currentMatch == null) {
        currentMatch = match;
      } else if (match.start <= currentMatch.end) {
        currentMatch = _Match(currentMatch.start,
            match.end > currentMatch.end ? match.end : currentMatch.end);
      } else {
        mergedMatches.add(currentMatch);
        currentMatch = match;
      }
    }
    if (currentMatch != null) {
      mergedMatches.add(currentMatch);
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in mergedMatches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(color: Colors.black87),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(color: Colors.black87),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  int _findOriginalPosition(
      String original, String normalized, int normalizedPos) {
    int originalPos = 0;
    int normalizedIndex = 0;

    while (normalizedIndex < normalizedPos && originalPos < original.length) {
      if (_isSeparator(original[originalPos])) {
        originalPos++;
        continue;
      }
      if (normalized[normalizedIndex] == original[originalPos].toLowerCase()) {
        normalizedIndex++;
      }
      originalPos++;
    }

    return originalPos;
  }

  bool _isSeparator(String char) {
    return RegExp(r'[-\s_.,;:/\\]').hasMatch(char);
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    Client client,
    DateTime date, {
    String? notes,
    int? routeId,
    String? routeName,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.assignment_add,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Confirm Journey Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please confirm the details of your journey plan:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      icon: Icons.person,
                      label: 'Client',
                      value: client.name,
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: DateFormat('EEEE, MMM dd, yyyy').format(date),
                      context: context,
                    ),
                    if (routeName != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.route,
                        label: 'Route',
                        value: routeName,
                        context: context,
                      ),
                    ],
                    if (client.address != null &&
                        client.address!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.location_on,
                        label: 'Address',
                        value: client.address!,
                        context: context,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create Plan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await createJourneyPlan(
        context,
        client.id,
        date,
        notes: notes,
        routeId: routeId,
        onSuccess: widget.onSuccess,
      );
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      _isCreatingJourneyPlan = true;
    });

    try {
      final newJourneyPlan = await ApiService.createJourneyPlan(
        clientId,
        date,
        notes: notes,
        routeId: routeId,
      );

      if (onSuccess != null) {
        onSuccess([newJourneyPlan]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Journey plan created successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Failed to create journey plan: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isCreatingJourneyPlan = false;
      });
    }
  }

  Widget _buildClientList() {
    return RefreshIndicator(
      onRefresh: _refreshClients,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: _isLoading && _isInitialLoad
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading clients...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _allClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clients available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Clients Assigned to this user',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // ElevatedButton.icon(
                        //   onPressed: () {
                        //     setState(() {
                        //       _isInitialLoad = true;
                        //     });
                        //     _initializeClients();
                        //   },
                        //   icon: const Icon(Icons.refresh, size: 18),
                        //   label: const Text('Retry'),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Theme.of(context).primaryColor,
                        //     foregroundColor: Colors.white,
                        //     padding: const EdgeInsets.symmetric(
                        //       horizontal: 16,
                        //       vertical: 8,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  )
                : filteredClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching clients found',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search terms',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount:
                            filteredClients.length + (_hasMoreData ? 1 : 0),
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          if (index == filteredClients.length) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final client = filteredClients[index];
                          return InkWell(
                            onTap: () async {
                              if (!_isLoading) {
                                // Add validation for selectedRouteId
                                if (selectedRouteId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: const [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Please select a route first.'),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                    ),
                                  );
                                  return;
                                }

                                String? routeName;
                                if (selectedRouteId != null) {
                                  try {
                                    final routes = await ApiService.getRoutes();
                                    final route = routes.firstWhere(
                                      (r) => r['id'] == selectedRouteId,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    routeName = route['name'];
                                  } catch (e) {
                                    // Handle error silently
                                  }
                                }

                                await _showConfirmationDialog(
                                  context,
                                  client,
                                  selectedDate,
                                  notes: notesController.text.trim(),
                                  routeId: selectedRouteId,
                                  routeName: routeName,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildHighlightedText(
                                            client.name, searchQuery),
                                        if (client.address != null &&
                                            client.address!.isNotEmpty)
                                          DefaultTextStyle(
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            child: _buildHighlightedText(
                                              client.address!,
                                              searchQuery,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: GradientAppBar(
        title: 'Create Journey Plan',
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: () async {
              // Show loading indicator in snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Refreshing client list...'),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              );

              // Refresh the client list
              await _refreshClients();

              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Client list refreshed'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Refresh client list',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 30)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: Theme.of(context)
                                                .colorScheme
                                                .copyWith(
                                                  primary: Theme.of(context)
                                                      .primaryColor,
                                                ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        selectedDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 18,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            DateFormat('MMM dd, yyyy')
                                                .format(selectedDate),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.route,
                                      size: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Route',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: ApiService.getRoutes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Container(
                                        height: 42,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Text(
                                        'Error loading routes',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade600,
                                        ),
                                      );
                                    }

                                    final routes = snapshot.data ?? [];
                                    return Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: selectedRouteId,
                                          isExpanded: true,
                                          icon:
                                              Icon(Icons.expand_more, size: 20),
                                          hint: const Text(
                                            'Select route',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          items: routes
                                              .map((route) =>
                                                  DropdownMenuItem<int>(
                                                    value: route['id'],
                                                    child: Text(
                                                      route['name'],
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedRouteId = value;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search clients...',
                      hintStyle:
                          TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) => Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Search Filters',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile.adaptive(
                                      dense: true,
                                      title: const Text('Search by Name'),
                                      value: _searchByName,
                                      onChanged: (value) {
                                        setState(() => _searchByName = value);
                                        _updateFilteredClients();
                                      },
                                    ),
                                    SwitchListTile.adaptive(
                                      dense: true,
                                      title: const Text('Search by Address'),
                                      value: _searchByAddress,
                                      onChanged: (value) {
                                        setState(
                                            () => _searchByAddress = value);
                                        _updateFilteredClients();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Client',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (filteredClients.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filteredClients.length} client${filteredClients.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildClientList(),
                ),
              ],
            ),
          ),
          // Loading overlay - only show for journey plan creation
          if (_isLoading && _isCreatingJourneyPlan)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Creating Journey Plan...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we process your request',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
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

  void _debugAuthStatus() {
    final box = GetStorage();
    final salesRep = box.read('salesRep');
    final routeId = ApiService.getCurrentUserRouteId();

    print('?? Debug Auth Status:');
    print('   SalesRep data: $salesRep');
    print('   Route ID: $routeId');
    print('   Initial clients count: ${widget.clients.length}');
  }
}
