import 'package:latlong2/latlong.dart';

class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  LatLng toLatLng() => LatLng(lat, lng);

  @override
  String toString() => 'GeoPoint(lat: $lat, lng: $lng)';
}
