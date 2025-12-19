import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/controllers/geocache_map_controller.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';
import 'package:transconnect/features/geocaching/utils/location_utils.dart';

class GeocacheMapScreen extends StatefulWidget {
  const GeocacheMapScreen({super.key});

  @override
  State<GeocacheMapScreen> createState() => _GeocacheMapScreenState();
}

class _GeocacheMapScreenState extends State<GeocacheMapScreen> {
  final MapController _mapController = MapController();

  GeocacheMapController? _ctrl;

  bool _locating = false;
  String? _locationError;
  bool _centering = false;

  static const GeoPoint _kentuckyCenter = GeoPoint(lat: 37.8393, lng: -84.2700);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ctrl != null) return;

    final repo = Provider.of<GeocacheRepository>(context, listen: false);
    _ctrl = GeocacheMapController(
      repo: repo,
      initialQuery: const GeocacheQuery(
        center: _kentuckyCenter,
        radiusMeters: 15000,
      ),
    )..start();
  }

  Future<void> _centerOnMyLocation() async {
    setState(() {
      _centering = true;
      _locationError = null;
    });

    try {
      final p = await LocationUtils.getCurrentPoint();
      if (!mounted) return;
      _mapController.move(p.toLatLng(), 15.0);
      _ctrl?.updateQuery(_ctrl!.query.copyWith(center: p));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _centering = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _placeAtMyLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final p = await LocationUtils.getCurrentPoint();
      if (!mounted) return;
      context.push('/geocaching/place', extra: p);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _locating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);

    final ctrl = _ctrl;
    if (ctrl == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final markers = ctrl.caches
            .where((c) => c.location != null)
            .map(
              (c) => Marker(
                width: 44,
                height: 44,
                point: LatLng(c.location!.lat, c.location!.lng),
                child: GestureDetector(
                  onTap: () => context.push('/geocaching/cache/${c.id}'),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
              ),
            )
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pins'),
            actions: [
              IconButton(
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
                onPressed: () async {
                  final next = await context.push<GeocacheQuery>(
                    '/geocaching/filters',
                    extra: ctrl.query,
                  );
                  if (next == null) return;
                  ctrl.updateQuery(next);
                },
              ),
              IconButton(
                tooltip: 'Recenter to Kentucky',
                icon: const Icon(Icons.public),
                onPressed: () {
                  _mapController.move(_kentuckyCenter.toLatLng(), 7.0);
                  ctrl.updateQuery(
                    ctrl.query.copyWith(center: _kentuckyCenter),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _kentuckyCenter.toLatLng(),
                  initialZoom: 7.0,
                  onLongPress: (tapPosition, latLng) {
                    if (!isAdmin) return;
                    context.push(
                      '/geocaching/place',
                      extra: GeoPoint(lat: latLng.latitude, lng: latLng.longitude),
                    );
                  },
                  onPositionChanged: (pos, hasGesture) {
                    if (!hasGesture) return;
                    final center = pos.center;
                    if (center == null) return;
                    ctrl.updateQuery(
                      ctrl.query.copyWith(
                        center: GeoPoint(lat: center.latitude, lng: center.longitude),
                      ),
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.transconnectky',
                  ),
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: markers,
                      maxClusterRadius: 45,
                      size: const Size(40, 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(50),
                      showPolygon: false,
                      rotate: false,
                      zoomToBoundsOnClick: true,
                      spiderfyCircleRadius: 80,
                      spiderfySpiralDistanceMultiplier: 1,
                      circleSpiralSwitchover: 12,
                      builder: (context, clusterMarkers) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              clusterMarkers.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              if (ctrl.loading)
                const Positioned(
                  top: 12,
                  left: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        'Loading pins…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              if (ctrl.error != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        ctrl.error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              if (_locationError != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _locationError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  onPressed: _locating ? null : _placeAtMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Add pin at my location'),
                )
              : FloatingActionButton(
                  onPressed: _centering ? null : _centerOnMyLocation,
                  child: _centering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
        );
      },
    );
  }
}
