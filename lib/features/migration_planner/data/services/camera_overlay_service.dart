import 'package:transconnect/features/migration_planner/data/flock_cameras.dart';
import 'package:transconnect/features/migration_planner/domain/models/camera_location.dart';

class CameraOverlayService {
  const CameraOverlayService();

  List<CameraLocation> getLocations() => FlockCameraLocations.cameras;
}
