import 'package:flutter/material.dart';

import '../../core/demo/demo_data.dart';
import '../../models/location.dart';
import '../../widgets/foss_map_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const location = demoEventLocation;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Community Feed Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text(demoFeedItems[0]),
          SizedBox(height: 24),
          Text('Map Widget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          FossMapWidget(
            location: Location(latitude: location.latitude, longitude: location.longitude),
            tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            attribution: '© OpenStreetMap contributors',
          ),
        ],
      ),
    );
  }
}
