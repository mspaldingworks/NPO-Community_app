import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_controller.dart';
import 'package:npo_community/main.dart';

void main() {
  test('demo workspace keeps task changes in memory', () {
    final controller = SupporterHubController.demo();

    expect(controller.openTaskCount, 4);
    controller.toggleTask('task-1');
    expect(controller.openTaskCount, 3);

    controller.addTask(
      title: 'Call the event host',
      owner: 'You',
      dueLabel: 'Today',
      project: 'Fall Benefit',
    );

    expect(controller.openTaskCount, 4);
    expect(controller.tasks.first.title, 'Call the event host');
  });

  testWidgets('demo starts in the supporter workspace on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      NpoCommunityApp(
        config: AppConfig.fromValues(
          environment: 'demo',
          apiOrigin: 'https://demo.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Maddie'), findsOneWidget);
    expect(find.text('Resources'), findsNothing);
    expect(find.text('The Meadow'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('4 open across NPO Community and Asana.'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
