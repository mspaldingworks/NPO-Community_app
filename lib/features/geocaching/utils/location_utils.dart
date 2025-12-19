import 'package:geolocator/geolocator.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';

class LocationUtils {
  static Future<GeoPoint> getCurrentPoint() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it in Settings.');
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    return GeoPoint(lat: pos.latitude, lng: pos.longitude);
  }
}
