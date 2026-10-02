import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/models/group.dart';
import 'package:npo_community/pages/community/regional_chats_screen.dart';

Map<String, dynamic> _region(
  int id,
  String name, {
  bool member = false,
  bool home = false,
}) => {
  'id': id,
  'name': name,
  'kind': 'regional',
  'slug': 'emky-region-$id',
  'region_id': 'region$id',
  'program_year': null,
  'is_member': member,
  'is_home': home,
};

void main() {
  test('Group reads kind, defaulting older payloads to custom', () {
    final cohort = Group.fromJson({
      'id': 1,
      'name': 'Class of 2019',
      'kind': 'cohort',
      'program_year': 2019,
      'region_id': '',
    });
    expect(cohort.isCohort, isTrue);
    expect(cohort.programYear, 2019);
    expect(cohort.regionId, isNull);

    final legacy = Group.fromJson({'id': 2, 'name': 'General'});
    expect(legacy.kind, 'custom');
    expect(legacy.isRegional || legacy.isCohort || legacy.isStatewide, isFalse);
  });

  testWidgets('regional groups show home region and join/leave', (
    tester,
  ) async {
    final calls = <String>[];
    var rows = [
      _region(1, 'Emerge KY — Central KY', member: true, home: true),
      _region(2, 'Emerge KY — Northern KY'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RegionalChatsScreen(
          loadRegions: () async => rows.map(RegionalGroup.fromJson).toList(),
          setMembership: (id, {required join}) async {
            calls.add('${join ? 'join' : 'leave'} $id');
            rows = [
              for (final r in rows)
                r['id'] == id ? {...r, 'is_member': join} : r,
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your region'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(calls, ['join 2']);
    expect(find.text('Leave'), findsNWidgets(2));
  });
}
