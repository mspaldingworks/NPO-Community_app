import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RoutePlan {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  const RoutePlan({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });
}
