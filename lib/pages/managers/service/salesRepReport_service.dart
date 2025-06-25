import 'package:get_storage/get_storage.dart';
import 'package:glamour_queen/models/report/report_model.dart';
import 'package:glamour_queen/models/user_model.dart';
import 'package:glamour_queen/services/api_service.dart';

class SalesRepReportService {
  final _apiService = ApiService();
  final _box = GetStorage();

  // Get sales reps that share the same route as the manager
  Future<List<SalesRep>> getSalesRepsByManagerRoute() async {
    try {
      final manager = _box.read('salesRep');
      if (manager == null) throw Exception('Manager data not found');

      final managerRouteId = manager['route_id'];
      if (managerRouteId == null) throw Exception('Manager route not found');

      // Call API to get sales reps with the same route_id
      final response = await ApiService.getSalesReps(routeId: managerRouteId);
      return response;
    } catch (e) {
      print('Error fetching sales reps: $e');
      rethrow;
    }
  }

  // Get reports for a specific sales rep with filters
  Future<List<Report>> getSalesRepReports({
    required int salesRepId,
    ReportType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final reports = await _apiService.getReports(
        salesRepId: salesRepId,
        type: type?.toString().split('.').last,
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );

      return reports;
    } catch (e) {
      print('Error fetching reports: $e');
      // Instead of rethrowing, we'll return an empty list if there's an error
      if (e.toString().contains('null: type \'Null\' is not a subtype of type \'String\'') ||
          e.toString().contains('type \'Null\' is not a subtype of type \'String\'')) {
        print('Known parsing error occurred. This is likely due to null data in the API response.');
        // Return empty list instead of throwing
        return [];
      }
      rethrow;
    }
  }

  // Get reports grouped by client for a sales rep
  Future<Map<int, List<Report>>> getReportsGroupedByClient({
    required int salesRepId,
    ReportType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final reports = await getSalesRepReports(
      salesRepId: salesRepId,
      type: type,
      startDate: startDate,
      endDate: endDate,
    );

    // Group reports by clientId
    return reports.fold<Map<int, List<Report>>>(
      {},
      (map, report) {
        map.putIfAbsent(report.clientId, () => []).add(report);
              return map;
      },
    );
  }
}

