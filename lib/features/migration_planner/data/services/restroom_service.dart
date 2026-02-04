import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/config/migration_planner_config.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/utils/restroom_utils.dart';

class RestroomService {
  RestroomService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? MigrationPlannerConfig.restroomBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  final Map<String, List<Restroom>> _routeCache = {};

  Future<List<Restroom>> fetchRestroomsAlongRoute({
    required String cacheKey,
    required List<LatLng> samples,
  }) async {
    final cached = _routeCache[cacheKey];
    if (cached != null) return cached;

    final results = <Restroom>[];
    for (final sample in samples) {
      final restrooms = await _fetchByLocation(sample);
      results.addAll(restrooms);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final unique = RestroomUtils.dedupe(results);
    _routeCache[cacheKey] = unique;
    return unique;
  }

  Future<List<Restroom>> _fetchByLocation(LatLng point) async {
    final uri = Uri.parse('$_baseUrl/restrooms/by_location').replace(
      queryParameters: {
        'lat': point.latitude.toString(),
        'lng': point.longitude.toString(),
        'page': '1',
        'per_page': '20',
      },
    );

    final response = await _getWithRetry(uri);
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => Restroom.fromJson(item as Map<String, dynamic>))
        .where((restroom) => restroom.latitude != 0 && restroom.longitude != 0)
        .toList();
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    const maxAttempts = 3;
    var attempt = 0;
    while (true) {
      attempt += 1;
      final response = await _client.get(uri);
      if (response.statusCode == 200) return response;
      if (attempt >= maxAttempts || response.statusCode < 500) {
        throw Exception('Refuge Restrooms request failed (${response.statusCode}).');
      }
      final delay = Duration(milliseconds: 300 * attempt);
      await Future<void>.delayed(delay);
    }
  }
}
