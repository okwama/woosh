import 'package:flutter/material.dart';
import 'package:woosh/services/token_debug_service.dart';
import 'package:woosh/services/token_service.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_widgets.dart';

class TokenDebugPage extends StatefulWidget {
  const TokenDebugPage({super.key});

  @override
  State<TokenDebugPage> createState() => _TokenDebugPageState();
}

class _TokenDebugPageState extends State<TokenDebugPage> {
  String _debugSummary = '';
  Map<String, dynamic> _tokenStatus = {};
  List<Map<String, dynamic>> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _debugSummary = TokenDebugService.getDebugSummary();
      _tokenStatus = TokenDebugService.getCurrentTokenStatus();
      _debugLogs = TokenDebugService.getDebugLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        title: const Text('Token Debug'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () async {
              await TokenDebugService.clearDebugLogs();
              _loadDebugInfo();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Token Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Token Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow('Authenticated',
                        _tokenStatus['isAuthenticated'] ?? false),
                    _buildStatusRow('Has Access Token',
                        _tokenStatus['hasAccessToken'] ?? false),
                    _buildStatusRow('Has Refresh Token',
                        _tokenStatus['hasRefreshToken'] ?? false),
                    _buildStatusRow(
                        'Token Expired', _tokenStatus['isExpired'] ?? true),
                    _buildStatusRow('Expiring Soon',
                        _tokenStatus['isExpiringSoon'] ?? false),
                    if (_tokenStatus['timeUntilExpiry'] != null)
                      _buildStatusRow(
                        'Time Until Expiry',
                        '${_tokenStatus['timeUntilExpiry']} minutes',
                        isStatus: false,
                      ),
                    if (_tokenStatus['expiryTime'] != null)
                      _buildStatusRow(
                        'Expiry Time',
                        _tokenStatus['expiryTime'],
                        isStatus: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Debug Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _debugSummary,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Debug Logs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_debugLogs.length} entries',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_debugLogs.isEmpty)
                      const Text('No debug logs available')
                    else
                      ..._debugLogs.take(10).map((log) => _buildLogEntry(log)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value, {bool isStatus = true}) {
    Color color;
    IconData icon;

    if (isStatus) {
      if (value == true) {
        color = Colors.green;
        icon = Icons.check_circle;
      } else {
        color = Colors.red;
        icon = Icons.cancel;
      }
    } else {
      color = Colors.blue;
      icon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final timestamp = DateTime.parse(log['timestamp']);
    final event = log['event'] as String;
    final details = log['details'] as Map<String, dynamic>?;

    Color eventColor;
    switch (event) {
      case 'logout':
        eventColor = Colors.red;
        break;
      case 'token_refresh_attempt':
        eventColor = Colors.orange;
        break;
      case '401_error':
        eventColor = Colors.purple;
        break;
      default:
        eventColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: eventColor, size: 8),
              const SizedBox(width: 8),
              Text(
                event,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: eventColor,
                ),
              ),
              const Spacer(),
              Text(
                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
