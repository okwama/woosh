import 'dart:async';
import 'package:woosh/utils/pagination_utils.dart';

class PaginatedService<T> {
  final Future<List<T>> Function({int page, int limit, String? search})
      fetchData;
  final int pageSize;
  final Duration debounceTime;
  Timer? _debounceTimer;
  bool _isLoading = false;
  Completer<PaginatedData<T>>? _currentCompleter;
  String? _currentSearch;

  PaginatedService({
    required this.fetchData,
    this.pageSize = 2000,
    this.debounceTime = const Duration(milliseconds: 300),
  });

  Future<PaginatedData<T>> loadInitialData() async {
    try {
      _isLoading = true;
      final items =
          await fetchData(page: 1, limit: pageSize, search: _currentSearch);
      return PaginatedData<T>(
        items: items,
        hasMore: items.length >= pageSize,
        currentPage: 1,
        totalPages: (items.length / pageSize).ceil(),
        isLoading: false,
      );
    } catch (e) {
      return PaginatedData<T>(
        items: [],
        hasMore: false,
        currentPage: 1,
        totalPages: 1,
        isLoading: false,
        error: e.toString(),
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<PaginatedData<T>> loadMoreData(PaginatedData<T> currentData) async {
    if (_isLoading || !currentData.hasMore) return currentData;

    _debounceTimer?.cancel();
    _currentCompleter?.completeError('Cancelled');
    _currentCompleter = Completer<PaginatedData<T>>();

    _debounceTimer = Timer(debounceTime, () async {
      try {
        _isLoading = true;
        final newItems = await fetchData(
          page: currentData.currentPage + 1,
          limit: pageSize,
          search: _currentSearch,
        );

        final updatedData = currentData.copyWith(
          items: [...currentData.items, ...newItems],
          hasMore: newItems.length >= pageSize,
          currentPage: currentData.currentPage + 1,
          totalPages:
              ((currentData.items.length + newItems.length) / pageSize).ceil(),
          isLoading: false,
        );
        _currentCompleter?.complete(updatedData);
      } catch (e) {
        final errorData = currentData.copyWith(
          isLoading: false,
          error: e.toString(),
        );
        _currentCompleter?.complete(errorData);
      } finally {
        _isLoading = false;
      }
    });

    return _currentCompleter!.future;
  }

  void updateSearch(String? search) {
    _currentSearch = search;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _currentCompleter?.completeError('Disposed');
  }
}
