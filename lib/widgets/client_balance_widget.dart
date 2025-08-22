import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/account_balance_service.dart';
import 'package:woosh/models/clients/client_model.dart';

class ClientBalanceWidget extends StatelessWidget {
  final Client client;
  final bool showFullDetails;
  final VoidCallback? onTap;

  const ClientBalanceWidget({
    Key? key,
    required this.client,
    this.showFullDetails = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AccountBalanceService>(
      builder: (balanceService) {
        final balanceInfo = balanceService.getClientBalance(client.id);
        final warning = balanceService.getBalanceWarning(client.id);
        
        if (balanceInfo == null) {
          return _buildLoadingWidget();
        }

        return InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(warning),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getBorderColor(warning),
                width: warning != null ? 2 : 1,
              ),
            ),
            child: showFullDetails 
                ? _buildDetailedView(balanceInfo, warning)
                : _buildCompactView(balanceInfo, warning),
          ),
        );
      },
    );
  }

  /// Build loading widget
  Widget _buildLoadingWidget() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading balance...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  /// Build compact view for lists
  Widget _buildCompactView(ClientBalanceInfo balanceInfo, BalanceWarning? warning) {
    return Row(
      children: [
        Icon(
          _getBalanceIcon(warning),
          color: _getIconColor(warning),
          size: 20,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance: ${balanceInfo.currency} ${balanceInfo.outstandingBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _getTextColor(warning),
                ),
              ),
              if (warning != null)
                Text(
                  warning.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getWarningColor(warning.severity),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        _buildCreditUtilizationIndicator(balanceInfo),
      ],
    );
  }

  /// Build detailed view for client details page
  Widget _buildDetailedView(ClientBalanceInfo balanceInfo, BalanceWarning? warning) {
    final availableCredit = balanceInfo.creditLimit - balanceInfo.outstandingBalance;
    final utilizationRate = balanceInfo.creditLimit > 0 
        ? (balanceInfo.outstandingBalance / balanceInfo.creditLimit)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with warning if applicable
        Row(
          children: [
            Icon(
              _getBalanceIcon(warning),
              color: _getIconColor(warning),
              size: 24,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Account Balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getTextColor(warning),
                ),
              ),
            ),
            if (warning != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getWarningColor(warning.severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getWarningColor(warning.severity)),
                ),
                child: Text(
                  _getWarningLabel(warning.severity),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getWarningColor(warning.severity),
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 12),
        
        // Balance details
        _buildBalanceRow('Outstanding Balance:', balanceInfo.outstandingBalance, balanceInfo.currency),
        _buildBalanceRow('Credit Limit:', balanceInfo.creditLimit, balanceInfo.currency),
        _buildBalanceRow(
          'Available Credit:', 
          availableCredit, 
          balanceInfo.currency,
          color: availableCredit < 0 ? Colors.red : Colors.green,
        ),
        
        SizedBox(height: 12),
        
        // Credit utilization bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credit Utilization',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${(utilizationRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getUtilizationColor(utilizationRate),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            LinearProgressIndicator(
              value: utilizationRate.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getUtilizationColor(utilizationRate),
              ),
            ),
          ],
        ),
        
        if (warning != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getWarningColor(warning.severity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.message,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _getWarningColor(warning.severity),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  warning.recommendedAction,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        SizedBox(height: 8),
        
        // Last payment info
        Row(
          children: [
            Icon(Icons.payment, size: 14, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              'Last payment: ${balanceInfo.currency} ${balanceInfo.lastPaymentAmount.toStringAsFixed(2)} on ${_formatDate(balanceInfo.lastPaymentDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  /// Build balance row
  Widget _buildBalanceRow(String label, double amount, String currency, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Build credit utilization indicator
  Widget _buildCreditUtilizationIndicator(ClientBalanceInfo balanceInfo) {
    final utilizationRate = balanceInfo.creditLimit > 0 
        ? (balanceInfo.outstandingBalance / balanceInfo.creditLimit)
        : 0.0;

    return Container(
      width: 40,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey[300],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: utilizationRate.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: _getUtilizationColor(utilizationRate),
          ),
        ),
      ),
    );
  }

  /// Get background color based on warning
  Color _getBackgroundColor(BalanceWarning? warning) {
    if (warning == null) return Colors.white;
    
    switch (warning.severity) {
      case BalanceWarningSeverity.high:
        return Colors.red[50]!;
      case BalanceWarningSeverity.medium:
        return Colors.orange[50]!;
      case BalanceWarningSeverity.low:
        return Colors.blue[50]!;
    }
  }

  /// Get border color based on warning
  Color _getBorderColor(BalanceWarning? warning) {
    if (warning == null) return Colors.grey[300]!;
    
    switch (warning.severity) {
      case BalanceWarningSeverity.high:
        return Colors.red[300]!;
      case BalanceWarningSeverity.medium:
        return Colors.orange[300]!;
      case BalanceWarningSeverity.low:
        return Colors.blue[300]!;
    }
  }

  /// Get balance icon based on warning
  IconData _getBalanceIcon(BalanceWarning? warning) {
    if (warning == null) return Icons.account_balance_wallet;
    
    switch (warning.severity) {
      case BalanceWarningSeverity.high:
        return Icons.error;
      case BalanceWarningSeverity.medium:
        return Icons.warning;
      case BalanceWarningSeverity.low:
        return Icons.info;
    }
  }

  /// Get icon color based on warning
  Color _getIconColor(BalanceWarning? warning) {
    if (warning == null) return Colors.blue;
    
    switch (warning.severity) {
      case BalanceWarningSeverity.high:
        return Colors.red;
      case BalanceWarningSeverity.medium:
        return Colors.orange;
      case BalanceWarningSeverity.low:
        return Colors.blue;
    }
  }

  /// Get text color based on warning
  Color _getTextColor(BalanceWarning? warning) {
    if (warning == null) return Colors.black87;
    
    switch (warning.severity) {
      case BalanceWarningSeverity.high:
        return Colors.red[700]!;
      case BalanceWarningSeverity.medium:
        return Colors.orange[700]!;
      case BalanceWarningSeverity.low:
        return Colors.blue[700]!;
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

  /// Get warning label
  String _getWarningLabel(BalanceWarningSeverity severity) {
    switch (severity) {
      case BalanceWarningSeverity.high:
        return 'CRITICAL';
      case BalanceWarningSeverity.medium:
        return 'WARNING';
      case BalanceWarningSeverity.low:
        return 'INFO';
    }
  }

  /// Get utilization color
  Color _getUtilizationColor(double utilization) {
    if (utilization >= 1.0) return Colors.red;
    if (utilization >= 0.8) return Colors.orange;
    if (utilization >= 0.6) return Colors.yellow[700]!;
    return Colors.green;
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Compact balance indicator for list items
class CompactBalanceIndicator extends StatelessWidget {
  final Client client;

  const CompactBalanceIndicator({
    Key? key,
    required this.client,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AccountBalanceService>(
      builder: (balanceService) {
        final warning = balanceService.getBalanceWarning(client.id);
        final balanceInfo = balanceService.getClientBalance(client.id);
        
        if (warning == null && balanceInfo == null) {
          return SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: warning != null 
                ? _getWarningColor(warning.severity).withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: warning != null 
                  ? _getWarningColor(warning.severity)
                  : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                warning != null ? Icons.warning : Icons.account_balance_wallet,
                size: 12,
                color: warning != null 
                    ? _getWarningColor(warning.severity)
                    : Colors.blue,
              ),
              SizedBox(width: 4),
              Text(
                balanceInfo != null 
                    ? '${balanceInfo.currency} ${balanceInfo.outstandingBalance.toStringAsFixed(0)}'
                    : 'Balance',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: warning != null 
                      ? _getWarningColor(warning.severity)
                      : Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
}