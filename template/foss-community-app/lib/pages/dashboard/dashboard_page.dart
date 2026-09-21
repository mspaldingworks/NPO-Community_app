import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/public_config.dart';
import '../../core/demo/demo_data.dart';
import '../../models/location.dart';
import '../../widgets/foss_map_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const location = demoEventLocation;
    final publicConfig = context.watch<PublicConfig>();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Community Feed Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(demoFeedItems[0]),
          const SizedBox(height: 24),
          const Text(
            'Map Widget',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FossMapWidget(
            location: Location(latitude: location.latitude, longitude: location.longitude),
            tileUrl: publicConfig.mapTileUrl,
            attribution: publicConfig.mapAttribution,
          ),
        ],
      ),
    );
  }
}
