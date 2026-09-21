import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/location.dart';

class FossMapWidget extends StatelessWidget {
  const FossMapWidget({
    super.key,
    required this.location,
    required this.tileUrl,
    required this.attribution,
  });

  final Location location;
  final String tileUrl;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(initialCenter: LatLng(location.latitude, location.longitude), initialZoom: 12),
        children: [
          TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'org.fosscommunity.app'),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(location.latitude, location.longitude),
                width: 48,
                height: 48,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
              ),
            ],
          ),
          RichAttributionWidget(attributions: [TextSourceAttribution(attribution)]),
        ],
      ),
    );
  }
}
