import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';

abstract class RoutingProvider {
  Future<RoutePlan> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool alternatives = true,
  });
}
