import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class RestroomDetailsSheet extends StatelessWidget {
  final Restroom restroom;

  const RestroomDetailsSheet({super.key, required this.restroom});

  @override
  Widget build(BuildContext context) {
    final location = LatLng(restroom.latitude, restroom.longitude);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(restroom.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (restroom.directions != null)
            Text('Directions: ${restroom.directions}', style: Theme.of(context).textTheme.bodyMedium),
          if (restroom.comment != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(restroom.comment!, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (restroom.accessible != null)
                Chip(
                  label: Text(restroom.accessible! ? 'Accessible' : 'Not accessible'),
                ),
              if (restroom.unisex != null)
                Chip(
                  label: Text(restroom.unisex! ? 'Unisex' : 'Not unisex'),
                ),
              if (restroom.updatedAt != null)
                Chip(
                  label: Text('Updated ${restroom.updatedAt}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(GeoUtils.geoUri(location, label: restroom.name));
              if (!await launchUrl(uri)) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open external maps.')),
                );
              }
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open in external maps'),
          ),
        ],
      ),
    );
  }
}
