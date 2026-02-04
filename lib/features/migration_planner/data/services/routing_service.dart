import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/data/services/osrm_routing_provider.dart';
import 'package:transconnect/features/migration_planner/data/services/routing_provider.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';
import 'package:transconnect/features/migration_planner/domain/utils/geo_utils.dart';

class RoutingService {
  RoutingService({RoutingProvider? provider}) : _provider = provider ?? OsrmRoutingProvider();

  final RoutingProvider _provider;

  Future<RoutePlan> planRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool alternatives = true,
  }) {
    return _provider.fetchRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      alternatives: alternatives,
    );
  }

  List<LatLng> sampleRoute(RoutePlan plan, {double intervalKm = 25}) {
    return GeoUtils.sampleEveryKilometers(plan.geometry, intervalKm);
  }
}
