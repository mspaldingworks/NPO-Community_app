import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transconnect/features/migration_planner/data/destinations.dart';
import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';
import 'package:transconnect/features/migration_planner/domain/models/route_plan.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_controller.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_screen.dart';
import 'package:transconnect/features/migration_planner/presentation/widgets/route_summary_card.dart';

void main() {
  testWidgets('Migration planner shows route summary and markers', (tester) async {
    final controller = MigrationPlannerController();
    await tester.pumpWidget(
      MaterialApp(
        home: MigrationPlannerScreen(controller: controller, showMap: false),
      ),
    );

    controller.setOrigin(const LatLng(37.5, -85.0));
    controller.setDestination(MigrationDestinations.all.first);

    const plan = RoutePlan(
      geometry: [LatLng(37.5, -85.0), LatLng(37.6, -85.1)],
      distanceMeters: 120000,
      durationSeconds: 7200,
      steps: [
        RouteStep(instruction: 'Head north', distanceMeters: 1000, durationSeconds: 600),
      ],
    );

    controller.setRoutePlanForTesting(
      plan,
      const [Restroom(id: 1, name: 'Test restroom', latitude: 37.55, longitude: -85.05)],
    );

    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      if (find.byType(RouteSummaryCard).evaluate().isNotEmpty) break;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(RouteSummaryCard), findsOneWidget);
    expect(find.text('Route summary'), findsOneWidget);
    expect(find.text('Restrooms along route'), findsOneWidget);
  });
}
