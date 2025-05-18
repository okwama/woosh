import 'dart:convert';
import 'package:woosh/models/report/feedbackReport_model.dart';
import 'package:woosh/models/report/productReport_model.dart';
import 'package:woosh/models/report/product_return_item_model.dart';
import 'package:woosh/models/report/product_sample_item_model.dart';
import 'package:woosh/models/report/visibilityReport_model.dart';
import 'package:woosh/models/report/productReturn_model.dart';
import 'package:woosh/models/report/productSample_model.dart';
import 'package:woosh/models/user_model.dart';
import 'package:woosh/models/client_model.dart';

enum ReportType {
  PRODUCT_AVAILABILITY,
  VISIBILITY_ACTIVITY,
  FEEDBACK,
  PRODUCT_RETURN,
  PRODUCT_SAMPLE, // Added PRODUCT_SAMPLE
}

class Report {
  final int? id;
  final ReportType type;
  final int? journeyPlanId;
  final int? salesRepId;
  final int? orderId;
  final int? clientId;
  final DateTime? createdAt;
  final SalesRep? user;
  final List<ProductReturnItem>? productReturnItems;
  final List<ProductSampleItem>? productSampleItems;

  // Related reports
  final ProductReport? productReport;
  final VisibilityReport? visibilityReport;
  final FeedbackReport? feedbackReport;
  final ProductReturn? productReturn;
  final ProductSample? productSample; // Added ProductSample

  final Client? client;

  Report({
    this.id,
    required this.type,
    this.journeyPlanId,
    this.salesRepId,
    this.orderId,
    this.clientId,
    this.createdAt,
    this.user,
    this.productReport,
    this.visibilityReport,
    this.feedbackReport,
    this.productReturn,
    this.productSample, // Added ProductSample
    this.productReturnItems,
    this.productSampleItems,
    this.client,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    try {
      print('DEBUG: Parsing Report JSON: $json');

      // Parse ID with validation
      final idValue = json['id'] != null 
          ? int.tryParse(json['id'].toString()) ?? 0 
          : 0;

      // Parse journeyPlanId with validation
      final journeyPlanIdValue = json['journeyPlanId'] != null 
          ? int.tryParse(json['journeyPlanId'].toString()) ?? null 
          : null;

      // Parse orderId with validation
      final orderIdValue = json['orderId'] != null 
          ? int.tryParse(json['orderId'].toString()) ?? null 
          : null;

      // Parse salesRepId with null-safety
      int? salesRepId;
      if (json['salesRepId'] != null) {
        salesRepId = int.tryParse(json['salesRepId'].toString());
      } else if (json['userId'] != null) {
        salesRepId = int.tryParse(json['userId'].toString());
      }

      // Parse clientId with null-safety
      int? clientId;
      if (json['clientId'] != null) {
        try {
          clientId = int.tryParse(json['clientId'].toString());
        } catch (e) {
          print('WARNING: Failed to parse clientId: $e');
        }
      }

      // Parse report type with validation and fallback
      ReportType reportType;
      try {
        final typeStr = json['type']?.toString().toUpperCase() ?? '';
        reportType = ReportType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => ReportType.PRODUCT_AVAILABILITY,
        );
        print('DEBUG: Parsed report type: $reportType');
      } catch (e) {
        print('ERROR: Failed to parse report type: $e, defaulting to PRODUCT_AVAILABILITY');
        reportType = ReportType.PRODUCT_AVAILABILITY;
      }

      // Parse specific report data with null safety
      ProductReport? productReport;
      VisibilityReport? visibilityReport;
      FeedbackReport? feedbackReport;
      ProductReturn? productReturn;
      ProductSample? productSample;
      List<ProductReturnItem>? productReturnItems;
      List<ProductSampleItem>? productSampleItems;

      // Try to parse the specific report based on the type
      try {
        final specificReportFieldName = _getSpecificReportFieldName(reportType);
        if (json[specificReportFieldName] != null) {
          final specificReportJson = json[specificReportFieldName];
          
          switch (reportType) {
            case ReportType.PRODUCT_AVAILABILITY:
              productReport = ProductReport.fromJson(specificReportJson);
              break;
            case ReportType.VISIBILITY_ACTIVITY:
              visibilityReport = VisibilityReport.fromJson(specificReportJson);
              break;
            case ReportType.FEEDBACK:
              feedbackReport = FeedbackReport.fromJson(specificReportJson);
              break;
            case ReportType.PRODUCT_RETURN:
              productReturn = ProductReturn.fromJson(specificReportJson);
              
              // Try to parse product return items
              if (json['productReturnItems'] != null && json['productReturnItems'] is List) {
                productReturnItems = (json['productReturnItems'] as List)
                    .map((itemJson) => ProductReturnItem.fromJson(itemJson))
                    .toList();
              }
              break;
            case ReportType.PRODUCT_SAMPLE:
              productSample = ProductSample.fromJson(specificReportJson);
              
              // Try to parse product sample items
              if (json['productSampleItems'] != null && json['productSampleItems'] is List) {
                productSampleItems = (json['productSampleItems'] as List)
                    .map((itemJson) => ProductSampleItem.fromJson(itemJson))
                    .toList();
              }
              break;
          }
        } else {
          print('DEBUG: Specific report field is null for type $reportType');
          print('DEBUG: JSON for specific report: ${json[_getSpecificReportFieldName(reportType)]}');
          // Create empty report based on type
          switch (reportType) {
            case ReportType.PRODUCT_AVAILABILITY:
              productReport = ProductReport(
                reportId: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
                productName: 'Unknown Product',
                quantity: 0,
                comment: 'Error parsing product report data',
              );
              break;
            case ReportType.VISIBILITY_ACTIVITY:
              visibilityReport = VisibilityReport(
                reportId: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
                comment: 'Error parsing visibility report data',
                imageUrl: null,
              );
              break;
            case ReportType.FEEDBACK:
              feedbackReport = FeedbackReport(
                reportId: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
                comment: 'Error parsing feedback report data',
              );
              break;
            case ReportType.PRODUCT_RETURN:
              productReturn = ProductReturn(
                reportId: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
                reason: 'Error parsing product return data',
                productName: 'Unknown Product',
                quantity: 0,
              );
              break;
            case ReportType.PRODUCT_SAMPLE:
              productSample = ProductSample(
                reportId: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
                reason: 'Error parsing product sample data',
                productName: 'Unknown Product',
                quantity: 0,
              );
              break;
          }
        }
      } catch (e) {
        print('WARNING: Failed to parse specific report data: $e');
        // Create a fallback specific report based on type
        switch (reportType) {
          case ReportType.PRODUCT_AVAILABILITY:
            productReport = ProductReport(
              reportId: idValue,
              productName: 'Error: Failed to parse',
              quantity: 0,
              comment: 'Error parsing report: $e',
            );
            break;
          case ReportType.VISIBILITY_ACTIVITY:
            visibilityReport = VisibilityReport(
              reportId: idValue,
              comment: 'Error parsing report: $e',
              imageUrl: null,
            );
            break;
          case ReportType.FEEDBACK:
            feedbackReport = FeedbackReport(
              reportId: idValue,
              comment: 'Error parsing report: $e',
            );
            break;
          case ReportType.PRODUCT_RETURN:
            productReturn = ProductReturn(
              reportId: idValue,
              reason: 'Error parsing report: $e',
              productName: 'Unknown Product',
              quantity: 0,
            );
            break;
          case ReportType.PRODUCT_SAMPLE:
            productSample = ProductSample(
              reportId: idValue,
              reason: 'Error parsing report: $e',
              productName: 'Unknown Product',
              quantity: 0,
            );
            break;
        }
      }

      // Parse user and client with field name normalization
      SalesRep? user;
      if (json['user'] != null) {
        try {
          user = SalesRep.fromJson(json['user']);
          print('DEBUG: Parsed user data');
        } catch (e) {
          print('WARNING: Failed to parse user data: $e');
        }
      } else if (json['User'] != null) {
        try {
          user = SalesRep.fromJson(json['User']);
          print('DEBUG: Parsed User data (PascalCase)');
        } catch (e) {
          print('WARNING: Failed to parse User data (PascalCase): $e');
        }
      }

      Client? client;
      if (json['client'] != null) {
        try {
          client = Client.fromJson(json['client']);
          print('DEBUG: Parsed client data');
        } catch (e) {
          print('WARNING: Failed to parse client data: $e');
        }
      } else if (json['Client'] != null) {
        try {
          client = Client.fromJson(json['Client']);
          print('DEBUG: Parsed Client data (PascalCase)');
        } catch (e) {
          print('WARNING: Failed to parse Client data (PascalCase): $e');
        }
      }

      // Parse DateTime with validation and retry
      DateTime? createdAt;
      if (json['createdAt'] != null) {
        try {
          final dateStr = json['createdAt'].toString();
          // Validate ISO 8601 format
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(dateStr)) {
            print('WARNING: Invalid date format: $dateStr');
            createdAt = DateTime.now();
          } else {
            createdAt = DateTime.tryParse(dateStr);
            if (createdAt == null) {
              print('WARNING: Failed to parse date: $dateStr');
              createdAt = DateTime.now();
            }
          }
        } catch (e) {
          print('ERROR: Failed to parse createdAt: $e');
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      // Sanitize string fields
      String sanitizeString(dynamic value) {
        if (value == null) return '';
        final str = value.toString().trim();
        return str.isEmpty ? '' : str;
      }

      print('DEBUG: Creating Report object with type: $reportType');
      
      return Report(
        id: idValue,
        type: reportType,
        journeyPlanId: journeyPlanIdValue,
        salesRepId: salesRepId,
        orderId: orderIdValue,
        clientId: clientId,
        createdAt: createdAt,
        user: user,
        productReport: productReport,
        visibilityReport: visibilityReport,
        feedbackReport: feedbackReport,
        productReturn: productReturn,
        productSample: productSample,
        productReturnItems: productReturnItems,
        productSampleItems: productSampleItems,
        client: client,
      );
    } catch (e) {
      print('ERROR: Failed to parse Report JSON: $e');
      print('DEBUG: JSON that caused the error: $json');
      
      // Instead of rethrowing, return a placeholder report
      final fallbackId = json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0;
      
      // Try to parse the report type, or default to PRODUCT_AVAILABILITY
      ReportType fallbackType;
      try {
        final typeStr = json['type']?.toString().toUpperCase() ?? '';
        fallbackType = ReportType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => ReportType.PRODUCT_AVAILABILITY,
        );
      } catch (_) {
        fallbackType = ReportType.PRODUCT_AVAILABILITY;
      }
      
      // Try to extract user information, even if minimal
      SalesRep? fallbackUser;
      try {
        if (json['user'] is Map) {
          final userData = json['user'] as Map;
          final userId = userData['id'] ?? 0;
          final userName = userData['name'] ?? 'Unknown User';
          fallbackUser = SalesRep(
            id: userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
            name: userName is String ? userName : userName.toString(),
            email: '',
            phoneNumber: '',
          );
        }
      } catch (_) {}
      
      // Create fallback client info if possible
      Client? fallbackClient;
      try {
        if (json['client'] is Map) {
          final clientData = json['client'] as Map;
          final clientId = clientData['id'] ?? 0;
          final clientName = clientData['name'] ?? 'Unknown Client';
          fallbackClient = Client(
            id: clientId is int ? clientId : int.tryParse(clientId.toString()) ?? 0,
            name: clientName is String ? clientName : clientName.toString(),
            address: clientData['address'] as String? ?? '',
            regionId: clientData['region_id'] as int? ?? 0,
            region: clientData['region'] as String? ?? '',
            countryId: clientData['countryId'] as int? ?? 0,
          );
        }
      } catch (_) {}
      
      // Create a fallback DateTime
      final fallbackDateTime = DateTime.now();
      
      return Report(
        id: fallbackId,
        type: fallbackType,
        salesRepId: json['userId'] != null ? int.tryParse(json['userId'].toString()) : null,
        clientId: json['clientId'] != null ? int.tryParse(json['clientId'].toString()) : null,
        createdAt: fallbackDateTime,
        user: fallbackUser,
        client: fallbackClient,
      );
    }
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
      if (_getSpecificReportJson() != null)
        'specificReport': _getSpecificReportJson(),
      'productReturn': productReturn?.toJson(),
      'productSample': productSample?.toJson(),
      if (productReturnItems != null)
        'productReturnItems':
            productReturnItems!.map((e) => e.toJson()).toList(),
      if (productSampleItems != null)
        'productSampleItems':
            productSampleItems!.map((e) => e.toJson()).toList(),
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
      case ReportType.PRODUCT_RETURN:
        return productReturn?.toJson();
      case ReportType.PRODUCT_SAMPLE: // Added case for ProductSample
        return productSample?.toJson();
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
      case ReportType.PRODUCT_RETURN:
        return productReturn?.reason ?? '';
      case ReportType.PRODUCT_SAMPLE: // Added ProductSample comment
        return productSample?.reason ??
            ''; // Assuming 'description' exists in ProductSample
      default:
        return '';
    }
  }

  // Getter to access the report image URL if available
  String? get displayImageUrl {
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

  // Null-safe display getters
  String get displayId => id?.toString() ?? 'N/A';
  String get displayType => type.toString().split('.').last.replaceAll('_', ' ');
  String get displayJourneyPlanId => journeyPlanId?.toString() ?? 'N/A';
  String get displaySalesRepId => salesRepId?.toString() ?? 'N/A';
  String get displayOrderId => orderId?.toString() ?? 'N/A';
  String get displayClientId => clientId?.toString() ?? 'N/A';
  String get displayCreatedAt => createdAt?.toLocal().toString() ?? 'N/A';
  
  // User and client display info
  String get displayUserName => user?.name ?? 'Unknown User';
  String get displayUserEmail => user?.email ?? 'No Email';
  String get displayUserPhone => user?.phoneNumber ?? 'No Phone';
  String get displayClientName => client?.name ?? 'Unknown Client';
  String get displayClientLocation => client?.location ?? 'No Location';

  // Report specific display info
  String get displayComment {
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        return productReport?.comment ?? 'No comment';
      case ReportType.VISIBILITY_ACTIVITY:
        return visibilityReport?.comment ?? 'No comment';
      case ReportType.FEEDBACK:
        return feedbackReport?.comment ?? 'No comment';
      case ReportType.PRODUCT_RETURN:
        return productReturn?.reason ?? 'No reason provided';
      case ReportType.PRODUCT_SAMPLE:
        return productSample?.reason ?? 'No reason provided';
      default:
        return 'No comment';
    }
  }

  // Product return items display
  List<Map<String, String>> get displayProductReturnItems {
    if (productReturnItems == null || productReturnItems!.isEmpty) {
      return [{'message': 'No return items'}];
    }
    return productReturnItems!.map((item) => {
      'product': item.productName ?? 'Unknown Product',
      'quantity': item.quantity?.toString() ?? '0',
      'reason': item.reason ?? 'No reason provided',
    }).toList();
  }

  // Product sample items display
  List<Map<String, String>> get displayProductSampleItems {
    if (productSampleItems == null || productSampleItems!.isEmpty) {
      return [{'message': 'No sample items'}];
    }
    return productSampleItems!.map((item) => {
      'product': item.productName ?? 'Unknown Product',
      'quantity': item.quantity?.toString() ?? '0',
      'reason': item.reason ?? 'No reason provided',
    }).toList();
  }

  // Product availability display
  Map<String, String> get displayProductAvailability {
    if (productReport == null) {
      return {
        'product': 'No product data',
        'quantity': 'N/A',
        'comment': 'No comment'
      };
    }
    return {
      'product': productReport!.productName ?? 'Unknown Product',
      'quantity': productReport!.quantity?.toString() ?? '0',
      'comment': productReport!.comment ?? 'No comment'
    };
  }

  // Visibility activity display
  Map<String, String> get displayVisibilityActivity {
    if (visibilityReport == null) {
      return {
        'comment': 'No visibility data',
        'image': 'No image'
      };
    }
    return {
      'comment': visibilityReport!.comment ?? 'No comment',
      'image': visibilityReport!.imageUrl ?? 'No image'
    };
  }

  // Feedback display
  Map<String, String> get displayFeedback {
    if (feedbackReport == null) {
      return {
        'comment': 'No feedback data'
      };
    }
    return {
      'comment': feedbackReport!.comment ?? 'No comment'
    };
  }

  // Product return display
  Map<String, dynamic> get displayProductReturn {
    if (productReturn == null) {
      return {
        'reason': 'No return data',
        'items': [{'message': 'No return items'}]
      };
    }
    return {
      'reason': productReturn!.reason ?? 'No reason provided',
      'items': displayProductReturnItems
    };
  }

  // Product sample display
  Map<String, dynamic> get displayProductSample {
    if (productSample == null) {
      return {
        'reason': 'No sample data',
        'items': [{'message': 'No sample items'}]
      };
    }
    return {
      'reason': productSample!.reason ?? 'No reason provided',
      'items': displayProductSampleItems
    };
  }

  // Get all display data as a map
  Map<String, dynamic> get displayData {
    return {
      'id': displayId,
      'type': displayType,
      'journeyPlanId': displayJourneyPlanId,
      'salesRepId': displaySalesRepId,
      'orderId': displayOrderId,
      'clientId': displayClientId,
      'createdAt': displayCreatedAt,
      'user': {
        'name': displayUserName,
        'email': displayUserEmail,
        'phone': displayUserPhone,
      },
      'client': {
        'name': displayClientName,
        'location': displayClientLocation,
      },
      'comment': displayComment,
      'imageUrl': displayImageUrl,
      'specificData': _getSpecificDisplayData(),
    };
  }

  Map<String, dynamic> _getSpecificDisplayData() {
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        return {'productAvailability': displayProductAvailability};
      case ReportType.VISIBILITY_ACTIVITY:
        return {'visibilityActivity': displayVisibilityActivity};
      case ReportType.FEEDBACK:
        return {'feedback': displayFeedback};
      case ReportType.PRODUCT_RETURN:
        return {'productReturn': displayProductReturn};
      case ReportType.PRODUCT_SAMPLE:
        return {'productSample': displayProductSample};
      default:
        return {'message': 'Unknown report type'};
    }
  }

  @override
  String toString() {
    return 'Report{'
        'id: $displayId, '
        'type: $displayType, '
        'journeyPlanId: $displayJourneyPlanId, '
        'salesRepId: $displaySalesRepId, '
        'orderId: $displayOrderId, '
        'clientId: $displayClientId, '
        'createdAt: $displayCreatedAt, '
        'user: $displayUserName, '
        'client: $displayClientName'
        '}';
  }

  static ReportType _parseReportType(dynamic type) {
    print('DEBUG: Parsing report type from: $type (${type.runtimeType})');
    
    if (type == null) {
      print('ERROR: Report type is null');
      throw Exception('Report type cannot be null');
    }

    // Handle both string and enum types
    String typeStr;
    if (type is String) {
      typeStr = type.toUpperCase().replaceAll(' ', '_');
    } else if (type is ReportType) {
      return type;
    } else {
      typeStr = type.toString().toUpperCase().replaceAll(' ', '_');
    }
    
    print('DEBUG: Normalized type string: $typeStr');

    // Try exact match first
    switch (typeStr) {
      case 'PRODUCT_AVAILABILITY':
        return ReportType.PRODUCT_AVAILABILITY;
      case 'VISIBILITY_ACTIVITY':
        return ReportType.VISIBILITY_ACTIVITY;
      case 'FEEDBACK':
        return ReportType.FEEDBACK;
      case 'PRODUCT_RETURN':
        return ReportType.PRODUCT_RETURN;
      case 'PRODUCT_SAMPLE':
        return ReportType.PRODUCT_SAMPLE;
      default:
        // Try partial match for legacy data
        if (typeStr.contains('PRODUCT') && typeStr.contains('AVAILABILITY')) {
          return ReportType.PRODUCT_AVAILABILITY;
        } else if (typeStr.contains('VISIBILITY') && typeStr.contains('ACTIVITY')) {
          return ReportType.VISIBILITY_ACTIVITY;
        } else if (typeStr.contains('FEEDBACK')) {
          return ReportType.FEEDBACK;
        } else if (typeStr.contains('PRODUCT') && typeStr.contains('RETURN')) {
          return ReportType.PRODUCT_RETURN;
        } else if (typeStr.contains('PRODUCT') && typeStr.contains('SAMPLE')) {
          return ReportType.PRODUCT_SAMPLE;
        }
        
        print('ERROR: Unknown report type: $typeStr');
        throw Exception('Unknown report type: $typeStr');
    }
  }

  // Helper method to get the correct field name for specific report types
  static String _getSpecificReportFieldName(ReportType type) {
    switch (type) {
      case ReportType.PRODUCT_AVAILABILITY:
        return 'productReport';
      case ReportType.VISIBILITY_ACTIVITY:
        return 'visibilityReport';
      case ReportType.FEEDBACK:
        return 'feedbackReport';
      case ReportType.PRODUCT_RETURN:
        return 'productReturn';
      case ReportType.PRODUCT_SAMPLE:
        return 'productSample';
      default:
        return '';
    }
  }
}
