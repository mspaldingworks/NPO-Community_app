import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_controller.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_screen.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_service.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';

class _FakeDirectoryService extends AlumniDirectoryService {
  _FakeDirectoryService(this.rows);

  final List<AlumniProfile> rows;

  @override
  Future<List<AlumniProfile>> fetchAlumni({
    String? search,
    int? cohortYear,
    String? volunteerRole,
  }) async => rows;
}

void main() {
  test('parses seeded-alumna fields and defaults older payloads', () {
    final seeded = AlumniProfile.fromJson({
      'account_id': 42,
      'van_id': null,
      'first_name': 'Bea',
      'last_name': 'Example',
      'cohort_year': 2012,
      'is_memorial': true,
      'claimed': false,
    });
    expect(seeded.accountId, 42);
    expect(seeded.isMemorial, isTrue);
    expect(seeded.claimed, isFalse);

    final legacy = AlumniProfile.fromJson({
      'van_id': 7,
      'first_name': 'Ada',
      'last_name': 'Example',
    });
    expect(legacy.accountId, isNull);
    expect(legacy.isMemorial, isFalse);
    expect(legacy.claimed, isTrue);
  });

  testWidgets('memorial profiles are labeled and not openable', (tester) async {
    final controller = AlumniDirectoryController(
      service: _FakeDirectoryService([
        AlumniProfile.fromJson({
          'account_id': 1,
          'first_name': 'Bea',
          'last_name': 'Example',
          'email': 'bea@example.org',
          'cohort_year': 2012,
          'is_memorial': true,
        }),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(home: AlumniDirectoryScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bea Example'), findsOneWidget);
    expect(find.textContaining('In memoriam'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Bea Example'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNull);
  });

  testWidgets('claimed alumnae get a Message button; unclaimed do not', (
    tester,
  ) async {
    final rows = [
      const AlumniProfile(
        vanId: 1,
        firstName: 'Claire',
        lastName: 'Claimed',
        accountId: 11,
        claimed: true,
      ),
      const AlumniProfile(
        vanId: 2,
        firstName: 'Una',
        lastName: 'Unclaimed',
        accountId: 12,
        claimed: false,
      ),
      const AlumniProfile(
        vanId: 3,
        firstName: 'Me',
        lastName: 'Myself',
        accountId: 99,
        claimed: true,
      ),
    ];
    final controller = AlumniDirectoryController(
      service: _FakeDirectoryService(rows),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AlumniDirectoryScreen(controller: controller, currentUserId: 99),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-11')), findsOneWidget);
    expect(find.byKey(const Key('message-12')), findsNothing);
    expect(find.byKey(const Key('message-99')), findsNothing);
    expect(find.textContaining("Hasn't joined yet"), findsOneWidget);

    // The sheet for an unclaimed alumna explains why there is no button.
    await tester.tap(find.text('Una Unclaimed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet-message')), findsNothing);
    expect(find.textContaining("hasn't claimed her profile"), findsOneWidget);
  });
}
