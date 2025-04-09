import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/models/report/visibilityReport_model.dart';
import 'package:woosh/models/report/feedbackReport_model.dart';

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
    Map<String, dynamic> details;
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        details = productReport?.toJson() ?? {};
        break;
      case ReportType.VISIBILITY_ACTIVITY:
        details = visibilityReport?.toJson() ?? {};
        break;
      case ReportType.FEEDBACK:
        details = feedbackReport?.toJson() ?? {};
        break;
    }

    return {
      'type': type.toString().split('.').last,
      'journeyPlanId': journeyPlanId,
      'userId': userId,
      'outletId': outletId,
      'details': details,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    // If the response contains a nested report structure, use the report object
    final reportData = json.containsKey('report') ? json['report'] : json;

    print('Processing report data: $reportData');
    print('Received type from server: ${reportData['type']}');
    print(
        'Available enum values: ${ReportType.values.map((e) => e.toString().split('.').last)}');

    final reportType = ReportType.values.firstWhere(
      (e) {
        final enumString = e.toString().split('.').last;
        print('Comparing $enumString with ${reportData['type']}');
        return enumString == reportData['type'];
      },
      orElse: () {
        print('No matching type found for ${reportData['type']}');
        throw Exception('Invalid report type: ${reportData['type']}');
      },
    );

    // Handle specific report data based on type
    Map<String, dynamic>? specificReportData;
    if (json.containsKey('specificReport')) {
      specificReportData = json['specificReport'];
    }

    return Report(
      id: reportData['id'],
      type: reportType,
      journeyPlanId: reportData['journeyPlanId'],
      userId: reportData['userId'],
      outletId: reportData['outletId'],
      createdAt: DateTime.parse(reportData['createdAt']),
      productReport: reportType == ReportType.PRODUCT_AVAILABILITY &&
              specificReportData != null
          ? ProductReport.fromJson(specificReportData)
          : null,
      visibilityReport: reportType == ReportType.VISIBILITY_ACTIVITY &&
              specificReportData != null
          ? VisibilityReport.fromJson(specificReportData)
          : null,
      feedbackReport:
          reportType == ReportType.FEEDBACK && specificReportData != null
              ? FeedbackReport.fromJson(specificReportData)
              : null,
    );
  }
}
