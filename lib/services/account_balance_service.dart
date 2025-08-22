import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/clients/client_model.dart';
import 'package:get_storage/get_storage.dart';

class AccountBalanceService extends GetxService {
  static AccountBalanceService get instance => Get.find<AccountBalanceService>();

  final GetStorage _storage = GetStorage();
  Timer? _balanceUpdateTimer;
  
  // Observable data
  final RxMap<int, ClientBalanceInfo> _clientBalances = <int, ClientBalanceInfo>{}.obs;
  final RxList<OverdueAccount> _overdueAccounts = <OverdueAccount>[].obs;
  final RxBool _isUpdating = false.obs;

  // Configuration
  static const int balanceUpdateIntervalMinutes = 15; // Update every 15 minutes
  static const double creditLimitWarningThreshold = 0.8; // 80% of credit limit
  static const int overdueDaysThreshold = 30; // 30 days overdue

  Map<int, ClientBalanceInfo> get clientBalances => _clientBalances;
  List<OverdueAccount> get overdueAccounts => _overdueAccounts;
  bool get isUpdating => _isUpdating.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadCachedBalanceData();
    _startBalanceUpdates();
  }

  @override
  void onClose() {
    _balanceUpdateTimer?.cancel();
    _saveCachedBalanceData();
    super.onClose();
  }

  /// Start periodic balance updates
  void _startBalanceUpdates() {
    _balanceUpdateTimer = Timer.periodic(
      Duration(minutes: balanceUpdateIntervalMinutes),
      (_) => _updateAllBalances(),
    );
    
    // Initial update
    _updateAllBalances();
  }

  /// Update all client balances
  Future<void> _updateAllBalances() async {
    if (_isUpdating.value) return;
    
    try {
      _isUpdating.value = true;
      
      // Fetch updated balance information
      final balanceData = await _fetchBalanceData();
      
      // Update local cache
      _updateLocalBalanceCache(balanceData);
      
      // Check for overdue accounts
      await _updateOverdueAccounts();
      
      print('✅ Balance data updated for ${_clientBalances.length} clients');
      
    } catch (e) {
      print('❌ Failed to update balance data: $e');
    } finally {
      _isUpdating.value = false;
    }
  }

  /// Fetch balance data from API
  Future<Map<int, ClientBalanceInfo>> _fetchBalanceData() async {
    try {
      // This would call your actual balance API
      final response = await ApiService.getClientBalances();
      
      final balanceMap = <int, ClientBalanceInfo>{};
      
      for (final balanceData in response) {
        final clientId = balanceData['clientId'] as int;
        final balance = ClientBalanceInfo.fromJson(balanceData);
        balanceMap[clientId] = balance;
      }
      
      return balanceMap;
      
    } catch (e) {
      print('Error fetching balance data: $e');
      throw Exception('Failed to fetch balance data');
    }
  }

  /// Update local balance cache
  void _updateLocalBalanceCache(Map<int, ClientBalanceInfo> newBalances) {
    for (final entry in newBalances.entries) {
      final clientId = entry.key;
      final newBalance = entry.value;
      final oldBalance = _clientBalances[clientId];
      
      // Check for significant balance changes
      if (oldBalance != null && _hasSignificantBalanceChange(oldBalance, newBalance)) {
        _notifyBalanceChange(clientId, oldBalance, newBalance);
      }
      
      _clientBalances[clientId] = newBalance;
    }
  }

  /// Check if there's a significant balance change
  bool _hasSignificantBalanceChange(ClientBalanceInfo oldBalance, ClientBalanceInfo newBalance) {
    final oldAmount = oldBalance.outstandingBalance;
    final newAmount = newBalance.outstandingBalance;
    
    // Consider it significant if change is more than 10% or 1000 units
    final percentageChange = (newAmount - oldAmount).abs() / oldAmount;
    return percentageChange > 0.1 || (newAmount - oldAmount).abs() > 1000;
  }

  /// Notify about balance changes
  void _notifyBalanceChange(int clientId, ClientBalanceInfo oldBalance, ClientBalanceInfo newBalance) {
    final client = _getClientName(clientId);
    final change = newBalance.outstandingBalance - oldBalance.outstandingBalance;
    
    if (change > 0) {
      // Balance increased (more debt)
      Get.snackbar(
        'Balance Update',
        '$client\'s outstanding balance increased by ${change.toStringAsFixed(2)}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } else {
      // Balance decreased (payment made)
      Get.snackbar(
        'Payment Received',
        '$client made a payment of ${(-change).toStringAsFixed(2)}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  /// Get client name by ID (you'd implement this based on your client data)
  String _getClientName(int clientId) {
    // This would fetch client name from your client service
    return 'Client #$clientId';
  }

  /// Update overdue accounts
  Future<void> _updateOverdueAccounts() async {
    try {
      final overdueData = await ApiService.getOverdueAccounts();
      
      _overdueAccounts.clear();
      for (final accountData in overdueData) {
        _overdueAccounts.add(OverdueAccount.fromJson(accountData));
      }
      
    } catch (e) {
      print('Error updating overdue accounts: $e');
    }
  }

  /// Get balance info for specific client
  ClientBalanceInfo? getClientBalance(int clientId) {
    return _clientBalances[clientId];
  }

  /// Check if client has outstanding balance
  bool hasOutstandingBalance(int clientId) {
    final balance = _clientBalances[clientId];
    return balance != null && balance.outstandingBalance > 0;
  }

  /// Check if client is near credit limit
  bool isNearCreditLimit(int clientId) {
    final balance = _clientBalances[clientId];
    if (balance == null || balance.creditLimit <= 0) return false;
    
    final utilizationRatio = balance.outstandingBalance / balance.creditLimit;
    return utilizationRatio >= creditLimitWarningThreshold;
  }

  /// Check if client is overdue
  bool isClientOverdue(int clientId) {
    return _overdueAccounts.any((account) => account.clientId == clientId);
  }

  /// Get balance warning for client
  BalanceWarning? getBalanceWarning(int clientId) {
    final balance = _clientBalances[clientId];
    if (balance == null) return null;

    // Check for overdue status
    if (isClientOverdue(clientId)) {
      final overdueAccount = _overdueAccounts.firstWhere(
        (account) => account.clientId == clientId,
      );
      
      return BalanceWarning(
        type: BalanceWarningType.overdue,
        message: 'Account is ${overdueAccount.daysPastDue} days overdue',
        severity: BalanceWarningSeverity.high,
        amount: overdueAccount.overdueAmount,
        recommendedAction: 'Collect payment before processing new orders',
      );
    }

    // Check for credit limit warning
    if (isNearCreditLimit(clientId)) {
      final availableCredit = balance.creditLimit - balance.outstandingBalance;
      
      return BalanceWarning(
        type: BalanceWarningType.creditLimit,
        message: 'Near credit limit - only ${availableCredit.toStringAsFixed(2)} available',
        severity: availableCredit <= 0 ? BalanceWarningSeverity.high : BalanceWarningSeverity.medium,
        amount: availableCredit,
        recommendedAction: availableCredit <= 0 
            ? 'Cannot process new orders - collect payment first'
            : 'Consider collecting payment before large orders',
      );
    }

    // Check for high outstanding balance
    if (balance.outstandingBalance > balance.creditLimit * 0.5) {
      return BalanceWarning(
        type: BalanceWarningType.highBalance,
        message: 'High outstanding balance: ${balance.outstandingBalance.toStringAsFixed(2)}',
        severity: BalanceWarningSeverity.low,
        amount: balance.outstandingBalance,
        recommendedAction: 'Consider discussing payment terms',
      );
    }

    return null;
  }

  /// Show balance warning dialog before order
  Future<bool> showBalanceWarningDialog(int clientId, double orderAmount) async {
    final warning = getBalanceWarning(clientId);
    if (warning == null) return true; // No warning needed

    final balance = _clientBalances[clientId];
    if (balance == null) return true;

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              _getWarningIcon(warning.severity),
              color: _getWarningColor(warning.severity),
            ),
            SizedBox(width: 8),
            Text('Balance Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning.message, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildBalanceDetails(balance, orderAmount),
            SizedBox(height: 12),
            Text(
              warning.recommendedAction,
              style: TextStyle(
                color: _getWarningColor(warning.severity),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel Order'),
          ),
          if (warning.severity != BalanceWarningSeverity.high)
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getWarningColor(warning.severity),
              ),
              child: Text('Proceed Anyway', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Build balance details widget
  Widget _buildBalanceDetails(ClientBalanceInfo balance, double orderAmount) {
    final newTotal = balance.outstandingBalance + orderAmount;
    final availableCredit = balance.creditLimit - newTotal;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceRow('Current Balance:', balance.outstandingBalance),
          _buildBalanceRow('Order Amount:', orderAmount),
          Divider(height: 16),
          _buildBalanceRow('New Total:', newTotal, isTotal: true),
          _buildBalanceRow('Credit Limit:', balance.creditLimit),
          _buildBalanceRow(
            'Available Credit:', 
            availableCredit,
            color: availableCredit < 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  /// Build balance row
  Widget _buildBalanceRow(String label, double amount, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get warning icon based on severity
  IconData _getWarningIcon(BalanceWarningSeverity severity) {
    switch (severity) {
      case BalanceWarningSeverity.high:
        return Icons.error;
      case BalanceWarningSeverity.medium:
        return Icons.warning;
      case BalanceWarningSeverity.low:
        return Icons.info;
    }
  }

  /// Get warning color based on severity
  Color _getWarningColor(BalanceWarningSeverity severity) {
    switch (severity) {
      case BalanceWarningSeverity.high:
        return Colors.red;
      case BalanceWarningSeverity.medium:
        return Colors.orange;
      case BalanceWarningSeverity.low:
        return Colors.blue;
    }
  }

  /// Load cached balance data
  Future<void> _loadCachedBalanceData() async {
    try {
      final cachedBalances = _storage.read<Map>('cached_balances');
      if (cachedBalances != null) {
        for (final entry in cachedBalances.entries) {
          final clientId = int.parse(entry.key);
          _clientBalances[clientId] = ClientBalanceInfo.fromJson(entry.value);
        }
      }
      
      final cachedOverdue = _storage.read<List>('cached_overdue_accounts');
      if (cachedOverdue != null) {
        _overdueAccounts.clear();
        for (final accountData in cachedOverdue) {
          _overdueAccounts.add(OverdueAccount.fromJson(accountData));
        }
      }
      
    } catch (e) {
      print('Error loading cached balance data: $e');
    }
  }

  /// Save cached balance data
  void _saveCachedBalanceData() {
    try {
      final balancesToCache = _clientBalances.map(
        (key, value) => MapEntry(key.toString(), value.toJson())
      );
      _storage.write('cached_balances', balancesToCache);
      
      final overdueToCache = _overdueAccounts.map((account) => account.toJson()).toList();
      _storage.write('cached_overdue_accounts', overdueToCache);
      
      _storage.write('balance_last_updated', DateTime.now().toIso8601String());
      
    } catch (e) {
      print('Error saving cached balance data: $e');
    }
  }

  /// Force refresh balance data
  Future<bool> forceRefreshBalances() async {
    try {
      await _updateAllBalances();
      
      Get.snackbar(
        'Balances Updated',
        'Client balance information has been refreshed.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return true;
      
    } catch (e) {
      Get.snackbar(
        'Update Failed',
        'Failed to refresh balance data: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return false;
    }
  }

  /// Get balance summary for all clients
  Map<String, dynamic> getBalanceSummary() {
    if (_clientBalances.isEmpty) {
      return {'error': 'No balance data available'};
    }

    double totalOutstanding = 0.0;
    double totalCreditLimit = 0.0;
    int clientsWithBalance = 0;
    int clientsNearLimit = 0;
    
    for (final balance in _clientBalances.values) {
      totalOutstanding += balance.outstandingBalance;
      totalCreditLimit += balance.creditLimit;
      
      if (balance.outstandingBalance > 0) {
        clientsWithBalance++;
      }
      
      if (balance.outstandingBalance / balance.creditLimit >= creditLimitWarningThreshold) {
        clientsNearLimit++;
      }
    }
    
    return {
      'totalClients': _clientBalances.length,
      'totalOutstanding': totalOutstanding,
      'totalCreditLimit': totalCreditLimit,
      'clientsWithBalance': clientsWithBalance,
      'clientsNearLimit': clientsNearLimit,
      'overdueAccounts': _overdueAccounts.length,
      'lastUpdated': _storage.read<String>('balance_last_updated'),
    };
  }

  /// Get clients that need payment collection
  List<int> getClientsNeedingPayment() {
    final clientsNeedingPayment = <int>[];
    
    // Add overdue clients
    for (final overdueAccount in _overdueAccounts) {
      clientsNeedingPayment.add(overdueAccount.clientId);
    }
    
    // Add clients near credit limit
    for (final entry in _clientBalances.entries) {
      final clientId = entry.key;
      final balance = entry.value;
      
      if (isNearCreditLimit(clientId) && !clientsNeedingPayment.contains(clientId)) {
        clientsNeedingPayment.add(clientId);
      }
    }
    
    return clientsNeedingPayment;
  }

  /// Check if order can be processed based on balance
  Future<OrderValidationResult> validateOrderAgainstBalance(int clientId, double orderAmount) async {
    final balance = _clientBalances[clientId];
    
    if (balance == null) {
      // Try to fetch balance if not cached
      try {
        await _updateClientBalance(clientId);
        final updatedBalance = _clientBalances[clientId];
        if (updatedBalance == null) {
          return OrderValidationResult(
            canProceed: false,
            warning: BalanceWarning(
              type: BalanceWarningType.unknown,
              message: 'Unable to verify client balance',
              severity: BalanceWarningSeverity.high,
              amount: 0.0,
              recommendedAction: 'Contact support to verify client credit status',
            ),
          );
        }
        return _validateOrderWithBalance(clientId, orderAmount, updatedBalance);
      } catch (e) {
        return OrderValidationResult(
          canProceed: false,
          warning: BalanceWarning(
            type: BalanceWarningType.unknown,
            message: 'Failed to check client balance',
            severity: BalanceWarningSeverity.high,
            amount: 0.0,
            recommendedAction: 'Check network connection and try again',
          ),
        );
      }
    }
    
    return _validateOrderWithBalance(clientId, orderAmount, balance);
  }

  /// Validate order with known balance
  OrderValidationResult _validateOrderWithBalance(int clientId, double orderAmount, ClientBalanceInfo balance) {
    // Check if client is overdue
    if (isClientOverdue(clientId)) {
      final overdueAccount = _overdueAccounts.firstWhere(
        (account) => account.clientId == clientId,
      );
      
      return OrderValidationResult(
        canProceed: false,
        warning: BalanceWarning(
          type: BalanceWarningType.overdue,
          message: 'Account is ${overdueAccount.daysPastDue} days overdue',
          severity: BalanceWarningSeverity.high,
          amount: overdueAccount.overdueAmount,
          recommendedAction: 'Collect overdue payment before processing new orders',
        ),
      );
    }

    // Check if order would exceed credit limit
    final newTotal = balance.outstandingBalance + orderAmount;
    if (newTotal > balance.creditLimit) {
      final excess = newTotal - balance.creditLimit;
      
      return OrderValidationResult(
        canProceed: false,
        warning: BalanceWarning(
          type: BalanceWarningType.creditLimit,
          message: 'Order would exceed credit limit by ${excess.toStringAsFixed(2)}',
          severity: BalanceWarningSeverity.high,
          amount: excess,
          recommendedAction: 'Reduce order amount or collect payment first',
        ),
      );
    }

    // Check if order would bring client near credit limit
    if (newTotal / balance.creditLimit >= creditLimitWarningThreshold) {
      final remainingCredit = balance.creditLimit - newTotal;
      
      return OrderValidationResult(
        canProceed: true,
        warning: BalanceWarning(
          type: BalanceWarningType.creditLimit,
          message: 'Order will bring client near credit limit',
          severity: BalanceWarningSeverity.medium,
          amount: remainingCredit,
          recommendedAction: 'Consider discussing payment terms',
        ),
      );
    }

    // Order is safe to proceed
    return OrderValidationResult(canProceed: true);
  }

  /// Update specific client balance
  Future<void> _updateClientBalance(int clientId) async {
    try {
      final balanceData = await ApiService.getClientBalance(clientId);
      _clientBalances[clientId] = ClientBalanceInfo.fromJson(balanceData);
    } catch (e) {
      print('Error updating client $clientId balance: $e');
      throw e;
    }
  }

  /// Get payment collection priority list
  List<PaymentCollectionItem> getPaymentCollectionPriority() {
    final items = <PaymentCollectionItem>[];
    
    // Add overdue accounts (highest priority)
    for (final overdueAccount in _overdueAccounts) {
      items.add(PaymentCollectionItem(
        clientId: overdueAccount.clientId,
        priority: PaymentPriority.urgent,
        amount: overdueAccount.overdueAmount,
        reason: '${overdueAccount.daysPastDue} days overdue',
        daysOverdue: overdueAccount.daysPastDue,
      ));
    }
    
    // Add clients near credit limit
    for (final entry in _clientBalances.entries) {
      final clientId = entry.key;
      final balance = entry.value;
      
      if (isNearCreditLimit(clientId) && !items.any((item) => item.clientId == clientId)) {
        items.add(PaymentCollectionItem(
          clientId: clientId,
          priority: PaymentPriority.high,
          amount: balance.outstandingBalance,
          reason: 'Near credit limit',
        ));
      }
    }
    
    // Sort by priority and amount
    items.sort((a, b) {
      final priorityComparison = a.priority.index.compareTo(b.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.amount.compareTo(a.amount); // Higher amounts first
    });
    
    return items;
  }
}

class ClientBalanceInfo {
  final int clientId;
  final double outstandingBalance;
  final double creditLimit;
  final DateTime lastPaymentDate;
  final double lastPaymentAmount;
  final String currency;

  ClientBalanceInfo({
    required this.clientId,
    required this.outstandingBalance,
    required this.creditLimit,
    required this.lastPaymentDate,
    required this.lastPaymentAmount,
    required this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'outstandingBalance': outstandingBalance,
      'creditLimit': creditLimit,
      'lastPaymentDate': lastPaymentDate.toIso8601String(),
      'lastPaymentAmount': lastPaymentAmount,
      'currency': currency,
    };
  }

  factory ClientBalanceInfo.fromJson(Map<String, dynamic> json) {
    return ClientBalanceInfo(
      clientId: json['clientId'],
      outstandingBalance: (json['outstandingBalance'] ?? 0.0).toDouble(),
      creditLimit: (json['creditLimit'] ?? 0.0).toDouble(),
      lastPaymentDate: DateTime.parse(json['lastPaymentDate'] ?? DateTime.now().toIso8601String()),
      lastPaymentAmount: (json['lastPaymentAmount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
    );
  }
}

class OverdueAccount {
  final int clientId;
  final double overdueAmount;
  final int daysPastDue;
  final DateTime oldestInvoiceDate;

  OverdueAccount({
    required this.clientId,
    required this.overdueAmount,
    required this.daysPastDue,
    required this.oldestInvoiceDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'overdueAmount': overdueAmount,
      'daysPastDue': daysPastDue,
      'oldestInvoiceDate': oldestInvoiceDate.toIso8601String(),
    };
  }

  factory OverdueAccount.fromJson(Map<String, dynamic> json) {
    return OverdueAccount(
      clientId: json['clientId'],
      overdueAmount: (json['overdueAmount'] ?? 0.0).toDouble(),
      daysPastDue: json['daysPastDue'] ?? 0,
      oldestInvoiceDate: DateTime.parse(json['oldestInvoiceDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class BalanceWarning {
  final BalanceWarningType type;
  final String message;
  final BalanceWarningSeverity severity;
  final double amount;
  final String recommendedAction;

  BalanceWarning({
    required this.type,
    required this.message,
    required this.severity,
    required this.amount,
    required this.recommendedAction,
  });
}

class OrderValidationResult {
  final bool canProceed;
  final BalanceWarning? warning;

  OrderValidationResult({
    required this.canProceed,
    this.warning,
  });
}

class PaymentCollectionItem {
  final int clientId;
  final PaymentPriority priority;
  final double amount;
  final String reason;
  final int? daysOverdue;

  PaymentCollectionItem({
    required this.clientId,
    required this.priority,
    required this.amount,
    required this.reason,
    this.daysOverdue,
  });
}

enum BalanceWarningType {
  overdue,
  creditLimit,
  highBalance,
  unknown,
}

enum BalanceWarningSeverity {
  low,
  medium,
  high,
}

enum PaymentPriority {
  urgent,
  high,
  medium,
  low,
}