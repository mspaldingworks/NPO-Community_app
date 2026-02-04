import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/config/migration_planner_config.dart';
import 'package:transconnect/features/migration_planner/data/services/polyline_decoder.dart';
import 'package:transconnect/features/migration_planner/data/services/routing_provider.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';

class OsrmRoutingProvider implements RoutingProvider {
  final http.Client _client;
  final String _baseUrl;

  OsrmRoutingProvider({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? MigrationPlannerConfig.routingBaseUrl;

  @override
  Future<RoutePlan> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    bool alternatives = true,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}',
    ).replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'polyline6',
        'steps': 'true',
        'alternatives': alternatives ? 'true' : 'false',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Routing request failed (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (payload['routes'] as List?) ?? const [];
    if (routes.isEmpty) {
      throw Exception('No routes returned by routing provider.');
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = PolylineDecoder.decode(route['geometry'] as String);
    final distance = (route['distance'] as num?)?.toDouble() ?? 0;
    final duration = (route['duration'] as num?)?.toDouble() ?? 0;

    final steps = <RouteStep>[];
    final legs = (route['legs'] as List?) ?? const [];
    for (final leg in legs) {
      final legSteps = (leg as Map<String, dynamic>)['steps'] as List? ?? const [];
      for (final step in legSteps) {
        final stepMap = step as Map<String, dynamic>;
        final instruction = stepMap['name'] as String? ?? 'Continue';
        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMeters: (stepMap['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (stepMap['duration'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }

    return RoutePlan(
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
    );
  }
}
