import 'package:transconnect/features/migration_planner/domain/models/camera_location.dart';

class FlockCameraLocations {
  FlockCameraLocations._();

  static const List<CameraLocation> cameras = [
    CameraLocation(
      id: 'ky-i65-bowling-green',
      name: 'Flock Camera: I-65 Bowling Green',
      latitude: 36.9685,
      longitude: -86.4808,
      description: 'Traffic safety camera location on I-65 near Bowling Green, KY.',
    ),
    CameraLocation(
      id: 'ky-i75-lexington',
      name: 'Flock Camera: I-75 Lexington',
      latitude: 38.0406,
      longitude: -84.5037,
      description: 'Camera near I-75 corridor by Lexington, KY.',
    ),
    CameraLocation(
      id: 'ky-i64-louisville',
      name: 'Flock Camera: I-64 Louisville',
      latitude: 38.2527,
      longitude: -85.7585,
      description: 'Camera near downtown Louisville, KY.',
    ),
  ];
}
