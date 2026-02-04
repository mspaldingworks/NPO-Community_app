import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/data/destinations.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_controller.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_screen.dart';

void main() {
  testWidgets('Migration planner shows route summary and markers', (tester) async {
    final controller = MigrationPlannerController();
    controller.setOrigin(const LatLng(37.5, -85.0));
    controller.setDestination(MigrationDestinations.all.first);

    final plan = RoutePlan(
      geometry: const [LatLng(37.5, -85.0), LatLng(37.6, -85.1)],
      distanceMeters: 120000,
      durationSeconds: 7200,
      steps: const [
        RouteStep(instruction: 'Head north', distanceMeters: 1000, durationSeconds: 600),
      ],
    );

    controller.setRoutePlanForTesting(
      plan,
      const [Restroom(id: 1, name: 'Test restroom', latitude: 37.55, longitude: -85.05)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MigrationPlannerScreen(controller: controller),
      ),
    );

    expect(find.text('Route summary'), findsOneWidget);
    expect(find.textContaining('Restrooms along route'), findsOneWidget);
  });
}
