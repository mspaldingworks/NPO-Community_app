import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/features/moderation/moderation_screen.dart';
import 'package:npo_community/features/moderation/moderation_service.dart';
import 'package:npo_community/models/user.dart';

class _FakeModerationService extends ModerationService {
  _FakeModerationService({
    this.reports = const [],
    this.members = const [],
    this.signups = const [],
    this.claims = const [],
  });

  final List<ModerationReport> reports;
  final List<ModerationMember> members;
  final List<PendingSignup> signups;
  final List<ClaimRecord> claims;
  final calls = <String>[];

  @override
  Future<ModerationPage<ModerationReport>> fetchReports({
    String status = 'active',
    int page = 1,
  }) async => ModerationPage(count: reports.length, results: reports);

  @override
  Future<ModerationPage<ModerationMember>> fetchMembers({
    String search = '',
    String status = '',
    int page = 1,
  }) async => ModerationPage(count: members.length, results: members);

  @override
  Future<ModerationPage<PendingSignup>> fetchSignups({int page = 1}) async =>
      ModerationPage(count: signups.length, results: signups);

  @override
  Future<ModerationPage<ClaimRecord>> fetchClaims({
    String status = '',
    String search = '',
    int page = 1,
  }) async => ModerationPage(count: claims.length, results: claims);

  @override
  Future<void> decideSignup(
    int accountId,
    String decision, {
    required String reason,
    int? seedAccountId,
  }) async => calls.add('$decision $accountId $seedAccountId $reason');

  @override
  Future<ClaimInvite> inviteClaim(
    int accountId, {
    required String email,
  }) async {
    calls.add('invite $accountId $email');
    return const ClaimInvite(
      code: 'ABCD-2345',
      message: 'Claim your profile with ABCD-2345.',
    );
  }

  @override
  Future<ModerationPage<AuditEntry>> fetchAudit({
    int? targetId,
    int page = 1,
  }) async => const ModerationPage(count: 0, results: []);

  @override
  Future<void> resolveReport(
    int reportId, {
    required String status,
    String notes = '',
  }) async => calls.add('resolve $reportId $status');

  @override
  Future<void> escalateReport(
    int reportId, {
    required String action,
    required String reason,
    DateTime? suspensionUntil,
  }) async => calls.add('escalate $reportId $action $reason');

  @override
  Future<void> memberAction(
    int memberId,
    String action, {
    required String reason,
    DateTime? suspensionUntil,
  }) async => calls.add('$action $memberId $reason');
}

ModerationReport _report() => ModerationReport.fromJson({
  'id': 7,
  'target_type': 'post',
  'reason': 'Harassment',
  'status': 'open',
  'created_at': '2026-10-02T12:00:00Z',
  'evidence': {'title': 'Hello', 'text': 'Rude words'},
  'reporter': {'id': 1, 'username': 'alice', 'display_name': 'Alice'},
  'target_user': {
    'id': 2,
    'username': 'bob',
    'display_name': 'Bob',
    'moderation_status': 'active',
  },
});

ModerationMember _member({bool protected = false, String status = 'active'}) =>
    ModerationMember.fromJson({
      'id': 2,
      'username': protected ? 'mod' : 'bob',
      'display_name': protected ? 'Mod' : 'Bob',
      'roles': protected ? ['moderator'] : ['alumni'],
      'moderation_status': status,
      'is_protected': protected,
      'program_year': 2021,
    });

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  test('report types map to API target types', () {
    expect(ReportTargetType.message.name, 'message');
    expect(ReportTargetType.chatMessage.name, 'chatMessage');
    expect(ReportTargetType.statusComment.name, 'statusComment');
  });

  test('canModerate comes from the server, falling back to staff flags', () {
    User user(Map<String, dynamic> extra) =>
        User.fromJson({'id': 1, 'username': 'u', ...extra});
    expect(user({'can_moderate': true}).canModerate, isTrue);
    expect(user({'is_staff': true}).canModerate, isTrue);
    expect(
      user({'is_staff': true, 'can_moderate': false}).canModerate,
      isFalse,
    );
    expect(user({}).canModerate, isFalse);
  });

  testWidgets('reports show evidence; dismiss and escalate', (tester) async {
    final service = _FakeModerationService(reports: [_report()]);
    await _pump(tester, ModerationScreen(service: service));

    expect(find.text('Post · Harassment'), findsOneWidget);
    expect(find.text('Hello\nRude words'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(service.calls, contains('resolve 7 dismissed'));

    await tester.tap(find.text('Act on member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restrict (read-only)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moderation-reason')),
      'Harassment again',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(service.calls, contains('escalate 7 restrict Harassment again'));
  });

  testWidgets('member actions need a reason', (tester) async {
    final service = _FakeModerationService(members: [_member()]);
    await _pump(tester, ModerationScreen(service: service, viewerId: 99));
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Warn'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Confirm');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('moderation-reason')),
      'Off topic',
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(service.calls, ['warn 2 Off topic']);
    // Lifting and roles are superuser-only.
    expect(find.text('Lift restriction'), findsNothing);
  });

  testWidgets('protected accounts are locked unless superuser', (tester) async {
    final service = _FakeModerationService(
      members: [_member(protected: true, status: 'warned')],
    );
    await _pump(tester, ModerationScreen(service: service, viewerId: 99));
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mod'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('only be actioned by a superuser'),
      findsOneWidget,
    );
    expect(find.text('Warn'), findsNothing);
  });

  testWidgets('superusers can lift and change roles', (tester) async {
    final service = _FakeModerationService(
      members: [_member(protected: true, status: 'warned')],
    );
    await _pump(
      tester,
      ModerationScreen(service: service, isSuperuser: true, viewerId: 99),
    );
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mod'));
    await tester.pumpAndSettle();
    expect(find.text('Warn'), findsOneWidget);
    expect(find.text('Lift restriction'), findsOneWidget);
    expect(find.text('Remove moderator'), findsOneWidget);
    expect(find.text('Make admin'), findsOneWidget);
  });

  testWidgets('signups link to a suggested roster match', (tester) async {
    final service = _FakeModerationService(
      signups: [
        PendingSignup.fromJson({
          'id': 5,
          'username': 'ada_example',
          'display_name': 'ada_example',
          'program_year': 2020,
          'suggestions': [
            {
              'id': 9,
              'username': 'ada-example',
              'display_name': 'Ada Example',
              'program_year': 2020,
            },
          ],
        }),
      ],
    );
    await _pump(tester, ModerationScreen(service: service));
    await tester.tap(find.text('Signups'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada Example (2020)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moderation-reason')),
      'Matches roster',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(service.calls, ['link 5 9 Matches roster']);
  });

  testWidgets('claim invites show the code once', (tester) async {
    final service = _FakeModerationService(
      claims: [
        ClaimRecord.fromJson({
          'id': 9,
          'username': 'ada-example',
          'display_name': 'Ada Example',
          'status': 'unclaimed',
          'program_year': 2020,
        }),
      ],
    );
    await _pump(tester, ModerationScreen(service: service));
    await tester.tap(find.text('Claims'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('claim-invite-email')),
      'ada@example.org',
    );
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();
    expect(service.calls, ['invite 9 ada@example.org']);
    expect(find.text('Claim code: ABCD-2345'), findsOneWidget);
    expect(find.text('Claim your profile with ABCD-2345.'), findsOneWidget);
  });
}
