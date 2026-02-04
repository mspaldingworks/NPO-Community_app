import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/data/services/polyline_decoder.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/utils/geo_utils.dart';
import 'package:transconnect/features/migration_planner/domain/utils/restroom_utils.dart';

void main() {
  test('PolylineDecoder decodes polyline5 example', () {
    const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final points = PolylineDecoder.decode(encoded, precision: 5);
    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 0.0001));
    expect(points.first.longitude, closeTo(-120.2, 0.0001));
    expect(points.last.latitude, closeTo(43.252, 0.0001));
    expect(points.last.longitude, closeTo(-126.453, 0.0001));
  });

  test('GeoUtils samples route at interval', () {
    final points = [
      const LatLng(37.0, -85.0),
      const LatLng(37.5, -85.0),
      const LatLng(38.0, -85.0),
    ];

    final samples = GeoUtils.sampleEveryKilometers(points, 30);
    expect(samples.first, points.first);
    expect(samples.last, points.last);
    expect(samples.length, greaterThanOrEqualTo(2));
  });

  test('RestroomUtils deduplicates by id and location', () {
    final restrooms = [
      const Restroom(id: 1, name: 'A', latitude: 38, longitude: -84),
      const Restroom(id: 1, name: 'A2', latitude: 38, longitude: -84),
      const Restroom(id: null, name: 'B', latitude: 38.00001, longitude: -84.00001),
      const Restroom(id: null, name: 'C', latitude: 38.00001, longitude: -84.00001),
    ];

    final deduped = RestroomUtils.dedupe(restrooms);
    expect(deduped.length, 2);
  });
}
