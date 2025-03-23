import 'package:whoosh/models/report/productReport_model.dart';
import 'package:whoosh/models/report/visibilityReport_model.dart';
import 'package:whoosh/models/report/feedbackReport_model.dart';

enum ReportType {
  PRODUCT_AVAILABILITY,
  VISIBILITY_ACTIVITY,
  FEEDBACK,
}

class Report {
  final int? id;
  final ReportType type;
  final int? journeyPlanId;
  final int userId;
  final int? orderId;
  final int outletId;
  final DateTime createdAt;

  // Optional related reports
  final ProductReport? productReport;
  final VisibilityReport? visibilityReport;
  final FeedbackReport? feedbackReport;

  Report({
    this.id,
    required this.type,
    this.journeyPlanId,
    required this.userId,
    this.orderId,
    required this.outletId,
    DateTime? createdAt,
    this.productReport,
    this.visibilityReport,
    this.feedbackReport,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'journeyPlanId': journeyPlanId,
      'userId': userId,
      'orderId': orderId,
      'outletId': outletId,
      'createdAt': createdAt.toIso8601String(),
      if (productReport != null) 'productReport': productReport!.toJson(),
      if (visibilityReport != null)
        'visibilityReport': visibilityReport!.toJson(),
      if (feedbackReport != null) 'feedbackReport': feedbackReport!.toJson(),
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      type: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      journeyPlanId: json['journeyPlanId'],
      userId: json['userId'],
      orderId: json['orderId'],
      outletId: json['outletId'],
      createdAt: DateTime.parse(json['createdAt']),
      productReport: json['productReport'] != null
          ? ProductReport.fromJson(json['productReport'])
          : null,
      visibilityReport: json['visibilityReport'] != null
          ? VisibilityReport.fromJson(json['visibilityReport'])
          : null,
      feedbackReport: json['feedbackReport'] != null
          ? FeedbackReport.fromJson(json['feedbackReport'])
          : null,
    );
  }
}
