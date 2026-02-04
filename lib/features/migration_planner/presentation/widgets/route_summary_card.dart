import 'package:flutter/material.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';

class RouteSummaryCard extends StatelessWidget {
  final RoutePlan plan;

  const RouteSummaryCard({super.key, required this.plan});

  String _formatDistance(double meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Distance: ${_formatDistance(plan.distanceMeters)}'),
            Text('Estimated time: ${_formatDuration(plan.durationSeconds)}'),
            const SizedBox(height: 8),
            Text('Steps', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...plan.steps.take(5).map(
                  (step) => Text('• ${step.instruction} (${_formatDistance(step.distanceMeters)})'),
                ),
            if (plan.steps.length > 5)
              Text('• +${plan.steps.length - 5} more steps'),
          ],
        ),
      ),
    );
  }
}
