import 'package:flutter/material.dart';

enum TargetType { SALES, VISITS, PRODUCT_PLACEMENT, CUSTOM }

class Target {
  final int? id;
  final String title;
  final String description;
  final TargetType type;
  final int userId;
  final int targetValue;
  final int currentValue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCompleted;

  Target({
    this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.userId,
    required this.targetValue,
    this.currentValue = 0,
    required this.startDate,
    required this.endDate,
    this.isCompleted = false,
  });

  // Calculate completion percentage
  double get completionPercentage =>
      targetValue > 0 ? (currentValue / targetValue) * 100 : 0;

  // Get color based on completion percentage
  Color get statusColor {
    if (isCompleted) return Colors.green;
    final percentage = completionPercentage;
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  // Get text representation of target type
  String get typeText {
    switch (type) {
      case TargetType.SALES:
        return 'Sales';
      case TargetType.VISITS:
        return 'Visits';
      case TargetType.PRODUCT_PLACEMENT:
        return 'Product Placement';
      case TargetType.CUSTOM:
        return 'Custom';
      default:
        return 'Unknown';
    }
  }

  // Check if target is active based on current date
  bool isActive() {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate) && !isCompleted;
  }

  // Check if target is overdue
  bool isOverdue() {
    final now = DateTime.now();
    return now.isAfter(endDate) && !isCompleted;
  }

  // Factory method to create a Target from JSON
  factory Target.fromJson(Map<String, dynamic> json) {
    return Target(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      type: _parseTargetType(json['type']),
      userId: json['userId'],
      targetValue: json['targetValue'],
      currentValue: json['currentValue'] ?? 0,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  // Convert Target to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'userId': userId,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  // Create a copy of this Target with specified changes
  Target copyWith({
    int? id,
    String? title,
    String? description,
    TargetType? type,
    int? userId,
    int? targetValue,
    int? currentValue,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
  }) {
    return Target(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // Helper method to parse target type from string
  static TargetType _parseTargetType(String typeStr) {
    switch (typeStr) {
      case 'SALES':
        return TargetType.SALES;
      case 'VISITS':
        return TargetType.VISITS;
      case 'PRODUCT_PLACEMENT':
        return TargetType.PRODUCT_PLACEMENT;
      case 'CUSTOM':
        return TargetType.CUSTOM;
      default:
        return TargetType.CUSTOM;
    }
  }
}
