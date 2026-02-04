import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/data/destinations.dart';
import 'package:transconnect/features/migration_planner/data/services/camera_overlay_service.dart';
import 'package:transconnect/features/migration_planner/data/services/restroom_service.dart';
import 'package:transconnect/features/migration_planner/data/services/routing_service.dart';
import 'package:transconnect/features/migration_planner/domain/models/camera_location.dart';
import 'package:transconnect/features/migration_planner/domain/models/destination.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';
import 'package:transconnect/features/migration_planner/domain/utils/geo_utils.dart';

class MigrationPlannerController extends ChangeNotifier {
  MigrationPlannerController({
    RoutingService? routingService,
    RestroomService? restroomService,
    CameraOverlayService? cameraOverlayService,
  })  : _routingService = routingService ?? RoutingService(),
        _restroomService = restroomService ?? RestroomService(),
        _cameraOverlayService = cameraOverlayService ?? const CameraOverlayService();

  static const LatLng _clarkMemorialBridgeWaypoint = LatLng(38.26361, -85.75139);
  static const double _ohioRiverDowntownLatitude = 38.27;
  static const double _downtownCorridorRadiusMeters = 9000;
  static const double _alreadyOnClarkRadiusMeters = 600;

  final RoutingService _routingService;
  final RestroomService _restroomService;
  final CameraOverlayService _cameraOverlayService;

  LatLng? _origin;
  DestinationType _destinationType = DestinationType.illinoisEntry;
  DestinationPreset? _destination;
  bool _includeAlternatives = true;
  bool _showRestrooms = true;
  bool _showCameras = true;
  double _sampleIntervalKm = 25;
  bool _isLoading = false;
  String? _errorMessage;
  RoutePlan? _routePlan;
  List<Restroom> _restrooms = [];

  LatLng? get origin => _origin;
  DestinationType get destinationType => _destinationType;
  DestinationPreset? get destination => _destination;
  bool get includeAlternatives => _includeAlternatives;
  bool get showRestrooms => _showRestrooms;
  bool get showCameras => _showCameras;
  double get sampleIntervalKm => _sampleIntervalKm;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RoutePlan? get routePlan => _routePlan;
  List<Restroom> get restrooms => _restrooms;
  List<DestinationPreset> get availableDestinations =>
      MigrationDestinations.byType(_destinationType);
  List<CameraLocation> get cameras => _cameraOverlayService.getLocations();

  void setOrigin(LatLng origin) {
    _origin = origin;
    notifyListeners();
  }

  void setDestinationType(DestinationType type) {
    _destinationType = type;
    _destination = null;
    notifyListeners();
  }

  void setDestination(DestinationPreset preset) {
    _destination = preset;
    notifyListeners();
  }

  void setIncludeAlternatives(bool value) {
    _includeAlternatives = value;
    notifyListeners();
  }

  void setShowRestrooms(bool value) {
    _showRestrooms = value;
    notifyListeners();
  }

  void setShowCameras(bool value) {
    _showCameras = value;
    notifyListeners();
  }

  void setSampleIntervalKm(double value) {
    _sampleIntervalKm = value;
    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    _errorMessage = null;
    notifyListeners();

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final request = await Geolocator.requestPermission();
      if (request == LocationPermission.denied || request == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission denied.';
        notifyListeners();
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _origin = LatLng(position.latitude, position.longitude);
    notifyListeners();
  }

  Future<void> planRoute() async {
    if (_origin == null || _destination == null) {
      _errorMessage = 'Select an origin and destination first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final destinationPoint = LatLng(_destination!.latitude, _destination!.longitude);
      final initial = await _routingService.planRoute(
        origin: _origin!,
        destination: destinationPoint,
        alternatives: _includeAlternatives,
      );

      var plan = initial;
      var usedClarkWaypoint = false;

      if (_routeAlreadyUsesClarkBridge(initial)) {
        usedClarkWaypoint = false;
      } else if (_shouldForceClarkBridge(initial)) {
        usedClarkWaypoint = true;
        plan = await _routingService.planRoute(
          origin: _origin!,
          destination: destinationPoint,
          waypoints: const [_clarkMemorialBridgeWaypoint],
          alternatives: _includeAlternatives,
        );
      }

      _routePlan = plan;

      if (_showRestrooms) {
        final samples = _routingService.sampleRoute(plan, intervalKm: _sampleIntervalKm);
        final cacheKey = _buildCacheKey(
          _origin!,
          _destination!,
          _sampleIntervalKm,
          viaClarkBridge: usedClarkWaypoint,
        );
        _restrooms = await _restroomService.fetchRestroomsAlongRoute(
          cacheKey: cacheKey,
          samples: samples,
        );
      } else {
        _restrooms = [];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setRoutePlanForTesting(RoutePlan plan, List<Restroom> restrooms) {
    _routePlan = plan;
    _restrooms = restrooms;
    notifyListeners();
  }

  bool _shouldForceClarkBridge(RoutePlan plan) {
    if (!_routeCrossesDowntownOhioRiver(plan)) return false;
    return _routePassesNearDowntownCorridor(plan);
  }

  bool _routeAlreadyUsesClarkBridge(RoutePlan plan) {
    for (final point in plan.geometry) {
      final distance = GeoUtils.distanceMeters(point, _clarkMemorialBridgeWaypoint);
      if (distance <= _alreadyOnClarkRadiusMeters) return true;
    }
    return false;
  }

  bool _routeCrossesDowntownOhioRiver(RoutePlan plan) {
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    for (final point in plan.geometry) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
    }
    return minLat < _ohioRiverDowntownLatitude && maxLat > _ohioRiverDowntownLatitude;
  }

  bool _routePassesNearDowntownCorridor(RoutePlan plan) {
    for (final point in plan.geometry) {
      final distance = GeoUtils.distanceMeters(point, _clarkMemorialBridgeWaypoint);
      if (distance <= _downtownCorridorRadiusMeters) return true;
    }
    return false;
  }

  String _buildCacheKey(
    LatLng origin,
    DestinationPreset destination,
    double intervalKm, {
    required bool viaClarkBridge,
  }) {
    return '${origin.latitude},${origin.longitude}|${destination.id}|${intervalKm.toStringAsFixed(1)}|clark=${viaClarkBridge ? 1 : 0}';
  }
}
