import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/alumni_running/alumni_candidates.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';

final _now = DateTime(2026, 10, 2, 12);

VolunteerOpportunity _event(String title, DateTime startsAt) =>
    VolunteerOpportunity(
      title: title,
      startsAt: startsAt,
      signupUrl: Uri.parse('https://signup.example/${title.hashCode}'),
    );

Future<List<Uri>> _pumpBallot(
  WidgetTester tester,
  List<AlumniCandidate> candidates,
) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: AlumniRunningScreen(
        candidates: candidates,
        showPhotos: false,
        now: () => _now,
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    ),
  );
  return opened;
}

void main() {
  group('curated list', () {
    test('is exactly the confirmed Emerge KY candidacies in the seed', () {
      final seed =
          jsonDecode(File('emerge_ky_seed.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(seed['meta']['org'], 'Emerge Kentucky');
      final confirmed = <String, String>{
        for (final alum in (seed['alumni'] as List).cast<Map>())
          if ((alum['candidacy_2026'] as Map?)?['show_on_card'] == true &&
              alum['candidacy_2026']['status'] == 'on_ballot' &&
              alum['is_deceased'] != true)
            alum['seed_id'] as String: alum['full_name'] as String,
      };
      expect(
        {for (final c in alumniCandidates2026) c.seedId!: c.name},
        confirmed,
        reason: 'Run python3 tool/ballot/build_ballot.py to resync.',
      );
    });

    test('every link is HTTPS and photos are not Ballotpedia-hosted', () {
      for (final c in alumniCandidates2026) {
        for (final uri in [
          c.campaignUrl,
          c.photoUrl,
          c.ballotpediaUrl,
          c.volunteerUrl,
          c.donateUrl,
          ...c.volunteerOpportunities.map((o) => o.signupUrl),
        ]) {
          if (uri != null) expect(uri.scheme, 'https', reason: c.name);
        }
        if (c.ballotpediaUrl != null) {
          expect(c.ballotpediaUrl!.host, 'ballotpedia.org', reason: c.name);
        }
        expect(c.photoUrl?.host, isNot(contains('ballotpedia')));
      }
    });
  });

  testWidgets('cards come down after Election Day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlumniRunningScreen(
          showPhotos: false,
          now: () => DateTime(2026, 11, 4, 8),
        ),
      ),
    );
    expect(find.byType(AlumniCandidateCard), findsNothing);
    expect(find.textContaining('election is over'), findsOneWidget);
  });

  group('upcomingOpportunities', () {
    test('hides past events and sorts the rest soonest first', () {
      final c = AlumniCandidate(
        name: 'Ada Example',
        office: 'City Council',
        election: 'Test',
        volunteerOpportunities: [
          _event('Later canvass', DateTime(2026, 10, 20, 10)),
          _event('Past phone bank', DateTime(2026, 9, 30, 18)),
          _event('Today, all day', DateTime(2026, 10, 2)),
          _event('Soon canvass', DateTime(2026, 10, 5, 9)),
        ],
      );
      expect(c.upcomingOpportunities(_now).map((o) => o.title), [
        'Today, all day',
        'Soon canvass',
        'Later canvass',
      ]);
    });

    test('an event with an end time counts until it ends', () {
      final event = VolunteerOpportunity(
        title: 'Shift',
        startsAt: DateTime(2026, 10, 2, 9),
        endsAt: DateTime(2026, 10, 2, 11),
        signupUrl: Uri.parse('https://signup.example'),
      );
      expect(event.hasEndedBy(DateTime(2026, 10, 2, 10)), isFalse);
      expect(event.hasEndedBy(DateTime(2026, 10, 2, 11)), isTrue);
    });
  });

  testWidgets('card shows race, links and upcoming volunteer events', (
    tester,
  ) async {
    final opened = await _pumpBallot(tester, [
      AlumniCandidate(
        name: 'Ada Example',
        office: 'Kentucky State Senate, District 6',
        election: 'Test Election',
        status: 'Won the Democratic primary',
        campaignUrl: Uri.parse('https://ada.example'),
        ballotpediaUrl: Uri.parse('https://ballotpedia.org/Ada_Example'),
        volunteerUrl: Uri.parse('https://ada.example/volunteer'),
        donateUrl: Uri.parse('https://ada.example/donate'),
        classYear: 2022,
        volunteerOpportunities: [
          _event('Past canvass', DateTime(2026, 9, 1, 10)),
          _event('Saturday canvass', DateTime(2026, 10, 10, 10)),
        ],
      ),
    ]);

    expect(find.text('Ballot'), findsOneWidget);
    expect(find.text('Ada Example'), findsOneWidget);
    expect(find.text('Kentucky State Senate, District 6'), findsOneWidget);
    expect(find.text('Won the Democratic primary'), findsOneWidget);
    expect(find.text('Emerge KY Class of 2022'), findsOneWidget);
    expect(find.text('AE'), findsOneWidget); // photos off → initials
    expect(find.text('Saturday canvass'), findsOneWidget);
    expect(find.text('Past canvass'), findsNothing);

    await tester.tap(find.text('Campaign website'));
    await tester.tap(find.text('Ballotpedia'));
    await tester.tap(find.text('Donate'));
    await tester.tap(find.text('Saturday canvass'));
    await tester.tap(find.text('Volunteer with the campaign'));
    await tester.pump();
    expect(opened, [
      Uri.parse('https://ada.example'),
      Uri.parse('https://ballotpedia.org/Ada_Example'),
      Uri.parse('https://ada.example/donate'),
      Uri.parse('https://signup.example/${'Saturday canvass'.hashCode}'),
      Uri.parse('https://ada.example/volunteer'),
    ]);
  });

  testWidgets('card without a website or events says so', (tester) async {
    await _pumpBallot(tester, [
      AlumniCandidate(
        name: 'Bea Example',
        office: 'City Council, At-large',
        election: 'Test Election',
        ballotpediaUrl: Uri.parse('https://ballotpedia.org/Bea_Example'),
      ),
    ]);

    expect(find.text('Campaign website'), findsNothing);
    expect(find.text('Ballotpedia'), findsOneWidget);
    expect(find.text('None listed yet. Check back soon.'), findsOneWidget);
    expect(find.text('Volunteer with the campaign'), findsNothing);
  });

  testWidgets('shows empty state without candidates', (tester) async {
    await _pumpBallot(tester, []);
    expect(find.byType(AlumniCandidateCard), findsNothing);
    expect(find.textContaining('No alumni candidates'), findsOneWidget);
  });
}
