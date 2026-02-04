import 'dart:math';

import 'package:latlong2/latlong.dart';

class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000;

  static double distanceMeters(LatLng a, LatLng b) {
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return _earthRadiusMeters * c;
  }

  static List<LatLng> sampleEveryKilometers(List<LatLng> points, double intervalKm) {
    if (points.length < 2 || intervalKm <= 0) return points;

    final intervalMeters = intervalKm * 1000;
    final samples = <LatLng>[points.first];
    var distanceSinceLast = 0.0;

    for (var i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      final segmentDistance = distanceMeters(start, end);
      distanceSinceLast += segmentDistance;

      if (distanceSinceLast >= intervalMeters) {
        samples.add(end);
        distanceSinceLast = 0.0;
      }
    }

    if (samples.last != points.last) {
      samples.add(points.last);
    }

    return samples;
  }

  static String geoUri(LatLng point, {String? label}) {
    final encodedLabel = label == null ? '' : Uri.encodeComponent(label);
    if (encodedLabel.isEmpty) {
      return 'geo:${point.latitude},${point.longitude}';
    }
    return 'geo:${point.latitude},${point.longitude}?q=$encodedLabel';
  }

  static double _degToRad(double degrees) => degrees * pi / 180;
}
