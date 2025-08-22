import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:woosh/services/order_status_tracking_service.dart';
import 'package:woosh/models/order_model.dart';

class OrderStatusWidget extends StatelessWidget {
  final Order order;
  final bool showHistory;
  final VoidCallback? onTap;

  const OrderStatusWidget({
    Key? key,
    required this.order,
    this.showHistory = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderStatusTrackingService>(
      builder: (statusService) {
        final currentStatus = statusService.getOrderStatus(order.id) ?? order.status.toString();
        final statusInfo = _getStatusInfo(currentStatus);
        final statusHistory = showHistory ? statusService.getOrderStatusHistory(order.id) : <OrderStatusUpdate>[];
        
        return InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusInfo['color'].withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(currentStatus, statusInfo),
                if (showHistory && statusHistory.isNotEmpty) ...[
                  SizedBox(height: 12),
                  _buildStatusHistory(statusHistory),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build status header
  Widget _buildStatusHeader(String currentStatus, Map<String, dynamic> statusInfo) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: statusInfo['color'],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            statusInfo['icon'],
            color: Colors.white,
            size: 16,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.id}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                statusInfo['label'],
                style: TextStyle(
                  color: statusInfo['color'],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIndicator(currentStatus),
      ],
    );
  }

  /// Build status indicator
  Widget _buildStatusIndicator(String status) {
    final isActive = _isActiveStatus(status);
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey,
      ),
      child: isActive 
          ? Container(
              width: 4,
              height: 4,
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  /// Build status history
  Widget _buildStatusHistory(List<OrderStatusUpdate> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        ...history.take(3).map((update) => _buildHistoryItem(update)),
        if (history.length > 3)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '+ ${history.length - 3} more updates',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  /// Build history item
  Widget _buildHistoryItem(OrderStatusUpdate update) {
    final statusInfo = _getStatusInfo(update.newStatus);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusInfo['color'],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              update.description,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
          Text(
            _formatTime(update.timestamp),
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Get status information
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return {
          'label': 'Draft',
          'color': Colors.grey,
          'icon': Icons.edit_note,
        };
      case 'PENDING':
        return {
          'label': 'Pending Review',
          'color': Colors.orange,
          'icon': Icons.schedule,
        };
      case 'APPROVED':
        return {
          'label': 'Approved',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'REJECTED':
        return {
          'label': 'Rejected',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      case 'IN_PROGRESS':
        return {
          'label': 'In Progress',
          'color': Colors.blue,
          'icon': Icons.sync,
        };
      case 'DELIVERED':
        return {
          'label': 'Delivered',
          'color': Colors.purple,
          'icon': Icons.local_shipping,
        };
      case 'CANCELLED':
        return {
          'label': 'Cancelled',
          'color': Colors.grey,
          'icon': Icons.block,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  /// Check if status is active (order is being processed)
  bool _isActiveStatus(String status) {
    final activeStatuses = ['PENDING', 'APPROVED', 'IN_PROGRESS'];
    return activeStatuses.contains(status.toUpperCase());
  }

  /// Format timestamp
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Live order status badge for compact display
class LiveOrderStatusBadge extends StatelessWidget {
  final Order order;
  final bool showPulse;

  const LiveOrderStatusBadge({
    Key? key,
    required this.order,
    this.showPulse = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderStatusTrackingService>(
      builder: (statusService) {
        final currentStatus = statusService.getOrderStatus(order.id) ?? order.status.toString();
        final statusInfo = _getStatusInfo(currentStatus);
        final isActive = _isActiveStatus(currentStatus);
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusInfo['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusInfo['color']),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive && showPulse)
                _buildPulseIndicator(statusInfo['color'])
              else
                Icon(
                  statusInfo['icon'],
                  size: 12,
                  color: statusInfo['color'],
                ),
              SizedBox(width: 4),
              Text(
                statusInfo['label'],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusInfo['color'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build pulse indicator for active orders
  Widget _buildPulseIndicator(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: 1),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3 + (0.7 * value)),
          ),
          child: Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }

  /// Get status information
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return {
          'label': 'Draft',
          'color': Colors.grey,
          'icon': Icons.edit_note,
        };
      case 'PENDING':
        return {
          'label': 'Pending',
          'color': Colors.orange,
          'icon': Icons.schedule,
        };
      case 'APPROVED':
        return {
          'label': 'Approved',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'REJECTED':
        return {
          'label': 'Rejected',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      case 'IN_PROGRESS':
        return {
          'label': 'Processing',
          'color': Colors.blue,
          'icon': Icons.sync,
        };
      case 'DELIVERED':
        return {
          'label': 'Delivered',
          'color': Colors.purple,
          'icon': Icons.local_shipping,
        };
      case 'CANCELLED':
        return {
          'label': 'Cancelled',
          'color': Colors.grey,
          'icon': Icons.block,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  /// Check if status is active
  bool _isActiveStatus(String status) {
    final activeStatuses = ['PENDING', 'APPROVED', 'IN_PROGRESS'];
    return activeStatuses.contains(status.toUpperCase());
  }
}

/// Order status timeline for detailed view
class OrderStatusTimeline extends StatelessWidget {
  final Order order;

  const OrderStatusTimeline({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderStatusTrackingService>(
      builder: (statusService) {
        final statusHistory = statusService.getOrderStatusHistory(order.id);
        
        if (statusHistory.isEmpty) {
          return _buildEmptyTimeline();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            ...statusHistory.map((update) => _buildTimelineItem(update)),
          ],
        );
      },
    );
  }

  /// Build empty timeline
  Widget _buildEmptyTimeline() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            'No status updates available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Build timeline item
  Widget _buildTimelineItem(OrderStatusUpdate update) {
    final statusInfo = _getStatusInfo(update.newStatus);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: statusInfo['color'],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusInfo['icon'],
                  color: Colors.white,
                  size: 14,
                ),
              ),
              Container(
                width: 2,
                height: 20,
                color: Colors.grey[300],
              ),
            ],
          ),
          
          SizedBox(width: 12),
          
          // Status details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo['label'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statusInfo['color'],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  update.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _formatDateTime(update.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get status information
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return {
          'label': 'Draft Created',
          'color': Colors.grey,
          'icon': Icons.edit_note,
        };
      case 'PENDING':
        return {
          'label': 'Pending Review',
          'color': Colors.orange,
          'icon': Icons.schedule,
        };
      case 'APPROVED':
        return {
          'label': 'Approved',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'REJECTED':
        return {
          'label': 'Rejected',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      case 'IN_PROGRESS':
        return {
          'label': 'Processing',
          'color': Colors.blue,
          'icon': Icons.sync,
        };
      case 'DELIVERED':
        return {
          'label': 'Delivered',
          'color': Colors.purple,
          'icon': Icons.local_shipping,
        };
      case 'CANCELLED':
        return {
          'label': 'Cancelled',
          'color': Colors.grey,
          'icon': Icons.block,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  /// Format date and time
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Quick order status summary for dashboard
class OrderStatusSummaryWidget extends StatelessWidget {
  const OrderStatusSummaryWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderStatusTrackingService>(
      builder: (statusService) {
        final summary = statusService.getOrderStatusSummary();
        final statusBreakdown = summary['statusBreakdown'] as Map<String, int>? ?? {};
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Order Status Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ...statusBreakdown.entries.map((entry) => 
                  _buildStatusSummaryRow(entry.key, entry.value)
                ),
                if (statusBreakdown.isEmpty)
                  Text(
                    'No orders to track',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build status summary row
  Widget _buildStatusSummaryRow(String status, int count) {
    final statusInfo = _getStatusInfo(status);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusInfo['color'],
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              statusInfo['label'],
              style: TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusInfo['color'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get status information
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return {'label': 'Draft Orders', 'color': Colors.grey};
      case 'PENDING':
        return {'label': 'Pending Review', 'color': Colors.orange};
      case 'APPROVED':
        return {'label': 'Approved Orders', 'color': Colors.green};
      case 'REJECTED':
        return {'label': 'Rejected Orders', 'color': Colors.red};
      case 'IN_PROGRESS':
        return {'label': 'In Progress', 'color': Colors.blue};
      case 'DELIVERED':
        return {'label': 'Delivered', 'color': Colors.purple};
      case 'CANCELLED':
        return {'label': 'Cancelled', 'color': Colors.grey};
      default:
        return {'label': status, 'color': Colors.grey};
    }
  }
}