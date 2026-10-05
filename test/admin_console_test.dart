import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/admin_console/admin_console_screen.dart';
import 'package:npo_community/features/admin_console/admin_console_service.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/models/user.dart';

const _overviewJson = {
  'generated_at': '2026-10-05T18:00:00Z',
  'members': {
    'total': 385,
    'claimed': 2,
    'unclaimed': 379,
    'invited': 0,
    'memorial': 4,
    'pending_signups': 1,
    'under_moderation': 0,
    'staff': 2,
    'volunteer_roles': {'mentor': 3, 'host': 1},
  },
  'moderation': {'open': 2, 'escalated': 0, 'total': 5},
  'fundraising': {
    'live': 1,
    'pending_review': 1,
    'closed': 0,
    'raised_cents': 18500,
    'donors': 6,
    'goal_cents': 50000,
    'mode': 'preview',
    'top': [],
  },
  'events': {
    'upcoming': 8,
    'rsvps_going': 12,
    'volunteer_shifts': 9,
    'volunteer_slots': 36,
    'open_slots': 30,
    'hours_logged': 2.5,
    'volunteers_logged': 1,
    'top_volunteers': [
      {'id': 1, 'display_name': 'Alice', 'hours': 2.5},
    ],
    'next': [],
  },
  'groups': {
    'statewide_members': 380,
    'candidates_members': 45,
    'regional': 6,
    'cohort': 17,
    'custom': 0,
  },
  'candidates': {'on_ballot': 45, 'next_election': '2026-11-03'},
  'integrations': {
    'van': {'configured': false, 'linked_accounts': 0, 'base_url': ''},
    'givebutter': {
      'mode': 'preview',
      'configured': false,
      'live_campaigns': 0,
      'review_required': true,
    },
    'email': {'enabled': false, 'from': ''},
    'image_screening': {'enabled': true},
  },
};

class _FakeAdmin extends AdminConsoleService {
  @override
  Future<AdminOverview> fetchOverview() async =>
      AdminOverview.fromJson(_overviewJson);
}

class _FakeFundraisers extends FundraisersService {
  final calls = <String>[];

  @override
  Future<List<Fundraiser>> fetchAll({String status = ''}) async {
    calls.add('all status=$status');
    return [
      Fundraiser(
        id: 1,
        templateKey: 'house_party',
        templateName: 'House party',
        templateIcon: 'home',
        title: 'House Party',
        status: status.isEmpty ? 'live' : status,
        goalCents: 50000,
        raisedCents: 18500,
        percent: 37,
      ),
    ];
  }
}

class _FakeEvents extends EventsService {
  @override
  Future<List<CommunityEvent>> fetchEvents({String when = 'upcoming'}) async =>
      [
        CommunityEvent(
          id: 1,
          title: 'Training Day',
          startsAt: DateTime(2027, 1, 10, 9),
        ),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AdminConsoleScreen(
        service: _FakeAdmin(),
        fundraisers: _FakeFundraisers(),
        events: _FakeEvents(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('User reads can_admin', () {
    expect(
      User.fromJson({'id': 1, 'username': 'a', 'can_admin': true}).canAdmin,
      isTrue,
    );
    expect(User.fromJson({'id': 1, 'username': 'a'}).canAdmin, isFalse);
    expect(
      User.fromJson({'id': 1, 'username': 'a', 'is_superuser': true}).canAdmin,
      isTrue,
    );
  });

  testWidgets('the overview sums the platform', (tester) async {
    await _pump(tester);
    expect(find.text('Control console'), findsOneWidget);
    expect(find.text('385'), findsOneWidget);
    expect(find.text('signups to review'), findsOneWidget);
    expect(find.text(r'$185'), findsOneWidget);
    expect(find.text('Preview until Givebutter is connected'), findsOneWidget);
    expect(find.text('alumnae on the ballot'), findsOneWidget);
    expect(find.byKey(const Key('stat-candidates-on-ballot')), findsOneWidget);
  });

  testWidgets('fundraising, events, volunteers and integrations tabs', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(Tab, 'Fundraising'));
    await tester.pumpAndSettle();
    expect(find.text('House Party'), findsOneWidget);
    await tester.tap(find.text('Awaiting review'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for review'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Events'));
    await tester.pumpAndSettle();
    expect(find.text('Training Day'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(Tab, 'Volunteers'));
    await tester.tap(find.widgetWithText(Tab, 'Volunteers'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Mentor a candidate · 3'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(Tab, 'Integrations'));
    await tester.tap(find.widgetWithText(Tab, 'Integrations'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('integration-van')), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
  });
}
