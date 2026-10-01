import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/alumni_running/alumni_candidates.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';

void main() {
  test('curated list includes the named 2026 alumni candidates', () {
    final names = alumniCandidates2026.map((c) => c.name).toSet();
    expect(
      names,
      containsAll(['Amy Olson', 'Serenity Johnson', 'Christian Furman']),
    );
    for (final c in alumniCandidates2026) {
      expect(c.primaryUrl, isNotNull, reason: c.name);
      expect(c.primaryUrl!.scheme, 'https', reason: c.name);
    }
  });

  test('campaign page is preferred over the info profile', () {
    final c = AlumniCandidate(
      name: 'Test Candidate',
      office: 'Office',
      election: 'Election',
      campaignUrl: Uri.parse('https://campaign.example'),
      infoUrl: Uri.parse('https://info.example'),
    );
    expect(c.primaryUrl.toString(), 'https://campaign.example');
    expect(c.hasCampaignPage, isTrue);
    expect(c.initials, 'TC');
  });

  testWidgets('renders candidate cards and opens links', (tester) async {
    final opened = <Uri>[];
    final candidates = [
      AlumniCandidate(
        name: 'Ada Example',
        office: 'City Council',
        election: 'Test Election',
        campaignUrl: Uri.parse('https://ada.example'),
      ),
      AlumniCandidate(
        name: 'Bea Example',
        office: 'State Senate',
        election: 'Test Election',
        infoUrl: Uri.parse('https://bea.example'),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AlumniRunningScreen(
          candidates: candidates,
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );

    expect(find.text('Ada Example'), findsOneWidget);
    expect(find.text('Bea Example'), findsOneWidget);
    expect(find.byType(AlumniCandidateCard), findsNWidgets(2));
    expect(find.text('Visit campaign page'), findsOneWidget);
    expect(find.text('View candidate info'), findsOneWidget);

    await tester.tap(find.text('Visit campaign page'));
    await tester.pump();
    expect(opened, [Uri.parse('https://ada.example')]);
  });

  testWidgets('shows empty state without candidates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AlumniRunningScreen(candidates: [])),
    );
    expect(find.byType(AlumniCandidateCard), findsNothing);
    expect(find.textContaining('No alumni candidates'), findsOneWidget);
  });
}
