import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';

class GeocacheQuery {
  final GeoPoint center;
  final double radiusMeters;
  final CacheStatus status;
  final String? text;

  const GeocacheQuery({
    required this.center,
    required this.radiusMeters,
    this.status = CacheStatus.active,
    this.text,
  });

  GeocacheQuery copyWith({
    GeoPoint? center,
    double? radiusMeters,
    CacheStatus? status,
    String? text,
  }) {
    return GeocacheQuery(
      center: center ?? this.center,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      status: status ?? this.status,
      text: text ?? this.text,
    );
  }
}
