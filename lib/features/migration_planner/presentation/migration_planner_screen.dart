import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/features/migration_planner/config/migration_planner_config.dart';
import 'package:transconnect/features/migration_planner/domain/models/destination.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/utils/geo_utils.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_controller.dart';
import 'package:transconnect/features/migration_planner/presentation/widgets/restroom_details_sheet.dart';
import 'package:transconnect/features/migration_planner/presentation/widgets/route_summary_card.dart';
import 'package:url_launcher/url_launcher.dart';

class MigrationPlannerScreen extends StatefulWidget {
  final MigrationPlannerController? controller;
  final bool showMap;

  const MigrationPlannerScreen({super.key, this.controller, this.showMap = true});

  @override
  State<MigrationPlannerScreen> createState() => _MigrationPlannerScreenState();
}

class _MigrationPlannerScreenState extends State<MigrationPlannerScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final FocusNode _latFocusNode = FocusNode();
  final FocusNode _lngFocusNode = FocusNode();
  final MapController _mapController = MapController();
  late final MigrationPlannerController _fallbackController;
  LatLng? _lastSyncedOrigin;

  @override
  void initState() {
    super.initState();
    _fallbackController = widget.controller ?? MigrationPlannerController();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _latFocusNode.dispose();
    _lngFocusNode.dispose();
    if (widget.controller == null) {
      _fallbackController.dispose();
    }
    super.dispose();
  }

  void _syncOriginFields(LatLng? origin) {
    if (origin == null) return;

    final last = _lastSyncedOrigin;
    if (last != null && last.latitude == origin.latitude && last.longitude == origin.longitude) {
      return;
    }

    // Don't clobber user input while they are typing.
    if (_latFocusNode.hasFocus || _lngFocusNode.hasFocus) return;

    _lastSyncedOrigin = origin;
    final nextLat = origin.latitude.toStringAsFixed(5);
    final nextLng = origin.longitude.toStringAsFixed(5);
    if (_latController.text != nextLat) _latController.text = nextLat;
    if (_lngController.text != nextLng) _lngController.text = nextLng;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MigrationPlannerController>.value(
      value: _fallbackController,
      child: Consumer<MigrationPlannerController>(
        builder: (context, controller, _) {
          _syncOriginFields(controller.origin);
          final origin = controller.origin;
          final destination = controller.destination;
          final routePlan = controller.routePlan;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Plan your migration'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSafetyCard(context),
                _buildOriginCard(context, controller),
                _buildDestinationCard(context, controller),
                _buildPreferencesCard(context, controller),
                if (controller.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      controller.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (widget.showMap)
                  SizedBox(
                    height: 360,
                    child: _buildMap(
                      context,
                      controller,
                      origin: origin,
                      destination: destination,
                    ),
                  ),
                if (routePlan != null) RouteSummaryCard(plan: routePlan),
                if (controller.restrooms.isNotEmpty)
                  _buildRestroomSummary(controller.restrooms),
                const SizedBox(height: 24),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.icon(
                  onPressed: controller.isLoading ? null : controller.planRoute,
                  icon: controller.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route_outlined),
                  label: Text(controller.isLoading ? 'Planning route...' : 'Plan route'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSafetyCard(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safety & legal notice', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'This planner provides public route information and nearby resources. '
              'Always follow local laws, prioritize personal safety, and contact emergency services if needed.',
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('911 for emergencies')),
                Chip(label: Text('Know your rights')),
                Chip(label: Text('Travel with trusted contacts')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginCard(BuildContext context, MigrationPlannerController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Origin (Kentucky)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    focusNode: _latFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    focusNode: _lngFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.useCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use current location'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    final lat = double.tryParse(_latController.text);
                    final lng = double.tryParse(_lngController.text);
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter valid coordinates.')),
                      );
                      return;
                    }
                    controller.setOrigin(LatLng(lat, lng));
                  },
                  child: const Text('Set origin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context, MigrationPlannerController controller) {
    final destinations = controller.availableDestinations;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destination presets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<DestinationType>(
              key: const ValueKey('migration_destination_type'),
              initialValue: controller.destinationType,
              decoration: const InputDecoration(labelText: 'Destination type'),
              items: const [
                DropdownMenuItem(
                  value: DestinationType.illinoisEntry,
                  child: Text('Nearest Illinois entry'),
                ),
                DropdownMenuItem(
                  value: DestinationType.canadaBorder,
                  child: Text('Canada border crossing'),
                ),
                DropdownMenuItem(
                  value: DestinationType.mexicoBorder,
                  child: Text('Mexico border crossing'),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.setDestinationType(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DestinationPreset>(
              key: ValueKey('migration_destination_${controller.destinationType.name}'),
              initialValue: controller.destination,
              decoration: const InputDecoration(labelText: 'Choose a destination'),
              items: destinations
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(preset.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.setDestination(value);
              },
            ),
            if (controller.destination != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.destination!.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (controller.destination != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final destinationPoint = LatLng(
                      controller.destination!.latitude,
                      controller.destination!.longitude,
                    );
                    final uri = Uri.parse(
                      GeoUtils.geoUri(destinationPoint, label: controller.destination!.name),
                    );
                    if (!await launchUrl(uri)) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open external maps.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open destination in maps'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, MigrationPlannerController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route preferences', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: controller.includeAlternatives,
              onChanged: controller.setIncludeAlternatives,
              title: const Text('Include alternate routes (if available)'),
            ),
            const SizedBox(height: 8),
            Text('Restroom sampling interval: ${controller.sampleIntervalKm.toStringAsFixed(0)} km'),
            Slider(
              value: controller.sampleIntervalKm,
              onChanged: controller.setSampleIntervalKm,
              min: 10,
              max: 80,
              divisions: 7,
              label: controller.sampleIntervalKm.toStringAsFixed(0),
            ),
            SwitchListTile.adaptive(
              value: controller.showRestrooms,
              onChanged: controller.setShowRestrooms,
              title: const Text('Show Refuge Restrooms along route'),
            ),
            SwitchListTile.adaptive(
              value: controller.showCameras,
              onChanged: controller.setShowCameras,
              title: const Text('Show Flock camera markers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestroomSummary(List<Restroom> restrooms) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Restrooms along route'),
            const SizedBox(height: 6),
            Text('${restrooms.length} restroom locations found.'),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    MigrationPlannerController controller, {
    required LatLng? origin,
    required DestinationPreset? destination,
  }) {
    final route = controller.routePlan;
    final markers = <Marker>[];

    if (origin != null) {
      markers.add(_buildMarker(
        origin,
        icon: Icons.trip_origin,
        color: Colors.blue,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Origin location selected.')),
          );
        },
      ));
    }

    if (destination != null) {
      final destinationPoint = LatLng(destination.latitude, destination.longitude);
      markers.add(_buildMarker(
        destinationPoint,
        icon: Icons.flag_outlined,
        color: Colors.green,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Destination: ${destination.name}')),
          );
        },
      ));
    }

    if (controller.showRestrooms) {
      for (final restroom in controller.restrooms) {
        markers.add(
          _buildMarker(
            LatLng(restroom.latitude, restroom.longitude),
            icon: Icons.wc,
            color: Colors.purple,
            onTap: () => _showRestroomDetails(context, restroom),
          ),
        );
      }
    }

    if (controller.showCameras) {
      for (final camera in controller.cameras) {
        markers.add(
          _buildMarker(
            LatLng(camera.latitude, camera.longitude),
            icon: Icons.videocam_outlined,
            color: Colors.red,
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(camera.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(camera.description),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    final polylines = <Polyline>[
      if (route != null)
        Polyline(
          points: route.geometry,
          color: Colors.blueAccent,
          strokeWidth: 4,
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: origin ?? const LatLng(37.8393, -84.2700),
        initialZoom: 6,
      ),
      children: [
        TileLayer(
          urlTemplate: MigrationPlannerConfig.tileServerUrl,
          userAgentPackageName: 'com.transconnect.app',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Marker _buildMarker(
    LatLng position, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Marker(
      width: 40,
      height: 40,
      point: position,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  void _showRestroomDetails(BuildContext context, Restroom restroom) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => RestroomDetailsSheet(restroom: restroom),
    );
  }
}
