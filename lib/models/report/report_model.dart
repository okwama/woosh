import 'dart:convert';
import 'package:woosh/models/report/feedbackReport_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/models/report/visibilityReport_model.dart';

enum ReportType {
  PRODUCT_AVAILABILITY,
  VISIBILITY_ACTIVITY,
  FEEDBACK,
}

class Report {
  final int? id;
  final ReportType type;
  final int? journeyPlanId;
  final int? salesRepId;
  final int? orderId;
  final int? clientId;
  final DateTime? createdAt;

  // Related reports
  final ProductReport? productReport;
  final VisibilityReport? visibilityReport;
  final FeedbackReport? feedbackReport;

  Report({
    this.id,
    required this.type,
    this.journeyPlanId,
    this.salesRepId,
    this.orderId,
    this.clientId,
    this.createdAt,
    this.productReport,
    this.visibilityReport,
    this.feedbackReport,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    print('Parsing Report with JSON: $json');

    // Parse IDs with error handling
    int? idValue =
        json['id'] != null ? int.tryParse(json['id'].toString()) : null;
    int? journeyPlanIdValue = json['journeyPlanId'] != null
        ? int.tryParse(json['journeyPlanId'].toString())
        : null;
    int? orderIdValue = json['orderId'] != null
        ? int.tryParse(json['orderId'].toString())
        : null;

    // Parse client and sales rep IDs, handling legacy 'outlet' and 'user' fields
    int? clientId = json['clientId'] != null
        ? int.tryParse(json['clientId'].toString())
        : (json['outletId'] != null
            ? int.tryParse(json['outletId'].toString())
            : null);

    int? salesRepId = json['salesRepId'] != null
        ? int.tryParse(json['salesRepId'].toString())
        : (json['userId'] != null
            ? int.tryParse(json['userId'].toString())
            : null);

    // Parse report type safely
    ReportType reportType;
    try {
      reportType = _parseReportType(json['type']);
    } catch (e) {
      print('Error parsing report type: $e');
      reportType = ReportType.FEEDBACK; // Default if we can't parse
    }

    // Initialize specific report types to null
    ProductReport? productReport;
    VisibilityReport? visibilityReport;
    FeedbackReport? feedbackReport;

    // Parse specific report data based on type
    try {
      switch (reportType) {
        case ReportType.PRODUCT_AVAILABILITY:
          if (json['productReport'] != null) {
            productReport = ProductReport.fromJson(json['productReport']);
          }
          break;
        case ReportType.VISIBILITY_ACTIVITY:
          if (json['visibilityReport'] != null) {
            visibilityReport =
                VisibilityReport.fromJson(json['visibilityReport']);
          }
          break;
        case ReportType.FEEDBACK:
          if (json['feedbackReport'] != null) {
            feedbackReport = FeedbackReport.fromJson(json['feedbackReport']);
          } else {
            // Create basic feedback report if missing
            int? reportId =
                json['id'] != null ? int.tryParse(json['id'].toString()) : null;
            feedbackReport = FeedbackReport(
              reportId: reportId ?? 0,
              comment: json['comment'] ?? '',
            );
          }
          break;
      }
    } catch (e) {
      print('Error parsing specific report data: $e');
      // Continue with basic report creation even if specific report parsing fails
    }

    print(
        'Creating Report object with: type=$reportType, salesRepId=$salesRepId, clientId=$clientId');
    return Report(
      id: idValue,
      type: reportType,
      journeyPlanId: journeyPlanIdValue,
      salesRepId: salesRepId,
      orderId: orderIdValue,
      clientId: clientId,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      productReport: productReport,
      visibilityReport: visibilityReport,
      feedbackReport: feedbackReport,
    );
  }

  Map<String, dynamic> toJson() {
    final typeString = type.toString().split('.').last;
    return {
      if (id != null) 'id': id,
      'type': typeString,
      if (journeyPlanId != null) 'journeyPlanId': journeyPlanId,
      if (salesRepId != null) 'salesRepId': salesRepId,
      if (orderId != null) 'orderId': orderId,
      if (clientId != null) 'clientId': clientId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      // Add specific report details based on type
      if (_getSpecificReportJson() != null)
        'specificReport': _getSpecificReportJson(),
    };
  }

  Map<String, dynamic>? _getSpecificReportJson() {
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        return productReport?.toJson();
      case ReportType.VISIBILITY_ACTIVITY:
        return visibilityReport?.toJson();
      case ReportType.FEEDBACK:
        return feedbackReport?.toJson();
      default:
        return null;
    }
  }

  // Getter to access the report comment regardless of type
  String get comment {
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        return productReport?.comment ?? '';
      case ReportType.VISIBILITY_ACTIVITY:
        return visibilityReport?.comment ?? '';
      case ReportType.FEEDBACK:
        return feedbackReport?.comment ?? '';
      default:
        return '';
    }
  }

  // Getter to access the report image URL if available
  String? get imageUrl {
    switch (type) {
      case ReportType.VISIBILITY_ACTIVITY:
        return visibilityReport?.imageUrl;
      default:
        return null;
    }
  }

  // Convenience method to create a product report
  static Report createProductReport({
    required int journeyPlanId,
    required int salesRepId,
    required int clientId,
    required String productName,
    int quantity = 0,
    String comment = '',
  }) {
    return Report(
      type: ReportType.PRODUCT_AVAILABILITY,
      journeyPlanId: journeyPlanId,
      salesRepId: salesRepId,
      clientId: clientId,
      productReport: ProductReport(
        reportId: 0, // Placeholder ID that will be replaced by the backend
        productName: productName,
        quantity: quantity,
        comment: comment,
      ),
    );
  }

  // Convenience method to create a visibility report
  static Report createVisibilityReport({
    required int journeyPlanId,
    required int salesRepId,
    required int clientId,
    required String comment,
    String? imageUrl,
  }) {
    return Report(
      type: ReportType.VISIBILITY_ACTIVITY,
      journeyPlanId: journeyPlanId,
      salesRepId: salesRepId,
      clientId: clientId,
      visibilityReport: VisibilityReport(
        reportId: 0, // Placeholder ID that will be replaced by the backend
        comment: comment,
        imageUrl: imageUrl,
      ),
    );
  }

  // Convenience method to create a feedback report
  static Report createFeedbackReport({
    required int journeyPlanId,
    required int salesRepId,
    required int clientId,
    required String comment,
  }) {
    return Report(
      type: ReportType.FEEDBACK,
      journeyPlanId: journeyPlanId,
      salesRepId: salesRepId,
      clientId: clientId,
      feedbackReport: FeedbackReport(
        reportId: 0, // Placeholder ID that will be replaced by the backend
        comment: comment,
      ),
    );
  }

  @override
  String toString() {
    return 'Report{id: $id, type: $type, journeyPlanId: $journeyPlanId, salesRepId: $salesRepId, clientId: $clientId, createdAt: $createdAt}';
  }

  // Static helper method to parse report type
  static ReportType _parseReportType(dynamic typeValue) {
    print(
        'Parsing report type from value: $typeValue (${typeValue.runtimeType})');
    if (typeValue == null) {
      throw ArgumentError('Invalid report type format: null');
    }

    String typeStr = typeValue.toString().toUpperCase();

    switch (typeStr) {
      case 'PRODUCT_AVAILABILITY':
      case 'PRODUCT':
        return ReportType.PRODUCT_AVAILABILITY;
      case 'VISIBILITY_ACTIVITY':
      case 'VISIBILITY':
        return ReportType.VISIBILITY_ACTIVITY;
      case 'FEEDBACK':
        return ReportType.FEEDBACK;
      default:
        print('Unknown report type: $typeStr');
        throw ArgumentError('Invalid report type format: $typeStr');
    }
  }
}
