import 'package:hive/hive.dart';
import '../../models/hive/route_model.dart';

class RouteHiveService {
  static const String _boxName = 'routes';
  late Box<RouteModel> _routeBox;

  Future<void> init() async {
    _routeBox = await Hive.openBox<RouteModel>(_boxName);
  }

  Future<void> saveRoute(RouteModel route) async {
    await _routeBox.put(route.id, route);
  }

  Future<void> saveRoutes(List<RouteModel> routes) async {
    final Map<int, RouteModel> routeMap = {
      for (var route in routes) route.id: route
    };
    await _routeBox.putAll(routeMap);
  }

  RouteModel? getRoute(int id) {
    return _routeBox.get(id);
  }

  List<RouteModel> getAllRoutes() {
    return _routeBox.values.toList();
  }

  Future<void> deleteRoute(int id) async {
    await _routeBox.delete(id);
  }

  Future<void> clearAllRoutes() async {
    await _routeBox.clear();
  }
}
