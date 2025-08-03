import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/offline_sync_service.dart';

class OfflineSyncIndicator extends StatefulWidget {
  const OfflineSyncIndicator({super.key});

  @override
  State<OfflineSyncIndicator> createState() => _OfflineSyncIndicatorState();
}

class _OfflineSyncIndicatorState extends State<OfflineSyncIndicator> {
  OfflineSyncService? _syncService;
  Map<String, int> _pendingCounts = {};
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initSyncService();
    _updateStatus();

    // Update status every 30 seconds
    Stream.periodic(const Duration(seconds: 30)).listen((_) {
      if (mounted) {
        _updateStatus();
      }
    });
  }

  Future<void> _initSyncService() async {
    try {
      _syncService = OfflineSyncService.instance;
      _updateStatus();
    } catch (e) {
    }
  }

  void _updateStatus() {
    if (_syncService == null) return;

    setState(() {
      _pendingCounts = _syncService!.getPendingOperationsCount();
      _isOnline = _syncService!.isOnline;
      _isSyncing = _syncService!.isSyncing;
    });
  }

  int get _totalPending {
    return _pendingCounts.values.fold(0, (sum, count) => sum + count);
  }

  @override
  Widget build(BuildContext context) {
    if (_syncService == null || _totalPending == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline
            ? (_isSyncing ? Colors.blue.shade50 : Colors.orange.shade50)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isOnline
              ? (_isSyncing ? Colors.blue.shade200 : Colors.orange.shade200)
              : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSyncing
                ? Icons.sync
                : (_isOnline ? Icons.cloud_upload : Icons.cloud_off),
            size: 16,
            color: _isOnline
                ? (_isSyncing ? Colors.blue.shade700 : Colors.orange.shade700)
                : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSyncing
                  ? 'Syncing $_totalPending items...'
                  : _isOnline
                      ? '$_totalPending items pending sync'
                      : '$_totalPending items saved offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _isOnline
                    ? (_isSyncing
                        ? Colors.blue.shade700
                        : Colors.orange.shade700)
                    : Colors.red.shade700,
              ),
            ),
          ),
          if (!_isSyncing && _isOnline && _totalPending > 0)
            InkWell(
              onTap: () async {
                await _syncService!.forcSync();
                _updateStatus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sync Now',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
