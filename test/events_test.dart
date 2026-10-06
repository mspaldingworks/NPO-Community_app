import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_controller.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_service.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/events/event_detail_screen.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/events/ics.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 5, 12);

CommunityEvent _event({
  int id = 1,
  String title = 'Alumnae Fall Social',
  DateTime? startsAt,
  bool isDemo = false,
  String? myRsvp,
  bool canManage = false,
  EventGroupRef? group,
  List<VolunteerShift> shifts = const [],
  bool isCancelled = false,
  bool isFavorite = false,
}) => CommunityEvent(
  id: id,
  title: title,
  startsAt: startsAt ?? _now.add(const Duration(days: 3)),
  endsAt: (startsAt ?? _now.add(const Duration(days: 3))).add(
    const Duration(hours: 2),
  ),
  locationName: 'Louisville',
  isDemo: isDemo,
  myRsvp: myRsvp,
  isFavorite: isFavorite,
  canManage: canManage,
  group: group,
  shifts: shifts,
  isCancelled: isCancelled,
  goingCount: myRsvp == 'going' ? 1 : 0,
  openVolunteerSlots: shifts.fold(0, (sum, s) => sum + s.openSlots),
  myShiftCount: shifts.where((s) => s.myClaim).length,
);

VolunteerShift _shift({int id = 10, bool myClaim = false, int open = 2}) =>
    VolunteerShift(
      id: id,
      roleName: 'Greeter',
      startsAt: _now.add(const Duration(days: 3)),
      endsAt: _now.add(const Duration(days: 3, hours: 2)),
      slots: 2,
      claimed: 2 - open,
      openSlots: open,
      myClaim: myClaim,
    );

class _FakeEvents extends EventsService {
  _FakeEvents(this.events, {this.mine = const MyCommitments()});

  List<CommunityEvent> events;
  MyCommitments mine;
  final calls = <String>[];

  CommunityEvent _byId(int id) => events.firstWhere((e) => e.id == id);

  @override
  Future<List<CommunityEvent>> fetchEvents({String when = 'upcoming'}) async {
    calls.add('list $when');
    return events;
  }

  @override
  Future<MyCommitments> fetchMine() async => mine;

  @override
  Future<CommunityEvent> fetchEvent(int id) async => _byId(id);

  @override
  Future<CommunityEvent> rsvp(int id, String status) async {
    calls.add('rsvp $id $status');
    final current = _byId(id);
    return _event(
      id: id,
      myRsvp: status,
      canManage: current.canManage,
      shifts: current.shifts,
    );
  }

  @override
  Future<CommunityEvent> setFavorite(int id, bool favorite) async {
    calls.add('favorite $id $favorite');
    final current = _byId(id);
    final updated = _event(
      id: id,
      title: current.title,
      myRsvp: current.myRsvp,
      canManage: current.canManage,
      shifts: current.shifts,
      isFavorite: favorite,
    );
    events = [
      for (final e in events)
        if (e.id == id) updated else e,
    ];
    return updated;
  }

  @override
  Future<CommunityEvent> claimShift(int id, int shiftId) async {
    calls.add('claim $id $shiftId');
    return _event(
      id: id,
      myRsvp: 'going',
      shifts: [_shift(id: shiftId, myClaim: true, open: 1)],
    );
  }

  @override
  Future<CommunityEvent> releaseShift(int id, int shiftId) async {
    calls.add('release $id $shiftId');
    return _event(
      id: id,
      shifts: [_shift(id: shiftId)],
    );
  }

  @override
  Future<CommunityEvent> addShift(
    int id, {
    required String roleName,
    required DateTime startsAt,
    required DateTime endsAt,
    int slots = 1,
    String description = '',
  }) async {
    calls.add('shift $id $roleName x$slots');
    return _event(id: id, canManage: true, shifts: [_shift()]);
  }

  @override
  Future<CommunityEvent> createEvent(EventDraft draft, {int? groupId}) async {
    calls.add('create ${draft.title} group=$groupId');
    final created = _event(id: 99, title: draft.title, canManage: true);
    events = [...events, created];
    return created;
  }
}

class _NoFundraisers extends FundraisersService {
  @override
  Future<List<Fundraiser>> fetchMine() async => const [];
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeEvents service, {
  bool canModerate = false,
  List<AlumniCandidate> candidates = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: EventsScreen(
        service: service,
        fundraisers: _NoFundraisers(),
        canModerate: canModerate,
        now: () => _now,
        candidates: candidates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(WidgetTester tester, _FakeEvents service) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: EventDetailScreen(eventId: 1, service: service, now: () => _now),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ics', () {
    test('builds a calendar file with escaped text and UTC stamps', () {
      final ics = buildIcs(
        CommunityEvent(
          id: 7,
          title: 'Coffee, downtown; bring friends',
          description: 'Line one\nLine two',
          startsAt: DateTime.utc(2026, 10, 10, 14),
          endsAt: DateTime.utc(2026, 10, 10, 15, 30),
          locationName: 'Heine Brothers',
        ),
      );
      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('UID:event-7@emergeky.app'));
      expect(ics, contains('DTSTART:20261010T140000Z'));
      expect(ics, contains('DTEND:20261010T153000Z'));
      expect(ics, contains(r'SUMMARY:Coffee\, downtown\; bring friends'));
      expect(ics, contains(r'DESCRIPTION:Line one\nLine two'));
      expect(ics, contains('LOCATION:Heine Brothers'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });

    test('defaults a missing end to two hours', () {
      final ics = buildIcs(
        CommunityEvent(
          id: 1,
          title: 'x',
          startsAt: DateTime.utc(2026, 10, 10, 14),
        ),
      );
      expect(ics, contains('DTEND:20261010T160000Z'));
    });
  });

  group('campaign shifts', () {
    final candidate = AlumniCandidate(
      name: 'Dana Beasley Brown',
      office: 'City Commission',
      election: '2026',
      volunteerOpportunities: [
        VolunteerOpportunity(
          title: 'Late canvass',
          startsAt: DateTime(2026, 10, 24, 10),
          signupUrl: Uri.parse('https://example.org/late'),
        ),
        VolunteerOpportunity(
          title: 'Early canvass',
          startsAt: DateTime(2026, 10, 10, 10),
          signupUrl: Uri.parse('https://example.org/early'),
        ),
        VolunteerOpportunity(
          title: 'Done canvass',
          startsAt: DateTime(2026, 10, 1, 10),
          signupUrl: Uri.parse('https://example.org/done'),
        ),
      ],
    );

    test('lists future shifts soonest first and hides past ones', () {
      final items = campaignItems(_now, candidates: [candidate]);
      expect(items.map((i) => i.opportunity.title), [
        'Early canvass',
        'Late canvass',
      ]);
    });

    test('goes quiet after Election Day', () {
      expect(
        campaignItems(DateTime(2026, 11, 5), candidates: [candidate]),
        [isEmpty].first,
      );
    });
  });

  group('EventsScreen', () {
    testWidgets('lists upcoming events in order with scope and status', (
      tester,
    ) async {
      final service = _FakeEvents([
        _event(
          id: 2,
          title: 'Later coffee',
          startsAt: _now.add(const Duration(days: 9)),
          group: const EventGroupRef(id: 5, name: 'Louisville', kind: 'region'),
          myRsvp: 'going',
        ),
        _event(id: 1, title: 'Fall Social', isDemo: true),
        _event(
          id: 3,
          title: 'Old thing',
          startsAt: _now.subtract(const Duration(days: 2)),
        ),
      ]);
      await _pumpScreen(tester, service);

      expect(service.calls, ['list all']);
      expect(find.text('Old thing'), findsNothing);
      final social = tester.getTopLeft(find.text('Fall Social'));
      final coffee = tester.getTopLeft(find.text('Later coffee'));
      expect(social.dy, lessThan(coffee.dy));
      expect(find.text('Statewide'), findsOneWidget);
      expect(find.text('Louisville'), findsWidgets);
      expect(find.text('Going'), findsOneWidget);
      expect(find.text('Sample'), findsNothing);
      expect(find.byKey(const Key('new-event')), findsNothing);
    });

    testWidgets('moderators see sample markers and can add an event', (
      tester,
    ) async {
      final service = _FakeEvents([_event(isDemo: true)]);
      await _pumpScreen(tester, service, canModerate: true);
      expect(find.text('Sample'), findsOneWidget);

      await tester.tap(find.byKey(const Key('new-event')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('event-title')),
        'Board retreat',
      );
      await tester.tap(find.byKey(const Key('event-save')));
      await tester.pumpAndSettle();

      expect(service.calls, contains('create Board retreat group=null'));
      expect(find.text('Board retreat'), findsOneWidget);
    });

    testWidgets('campaign shifts from the Ballot page sit in the list', (
      tester,
    ) async {
      final candidate = AlumniCandidate(
        name: 'Jane Doe',
        office: 'State House',
        election: '2026',
        volunteerOpportunities: [
          VolunteerOpportunity(
            title: 'Saturday canvass',
            startsAt: _now.add(const Duration(days: 1)),
            signupUrl: Uri.parse('https://example.org/canvass'),
          ),
        ],
      );
      await _pumpScreen(
        tester,
        _FakeEvents([_event()]),
        candidates: [candidate],
      );
      expect(find.text('Saturday canvass'), findsOneWidget);
      expect(find.text('Campaign · Jane Doe'), findsOneWidget);
      final canvass = tester.getTopLeft(find.text('Saturday canvass'));
      final social = tester.getTopLeft(find.text('Alumnae Fall Social'));
      expect(canvass.dy, lessThan(social.dy));
    });

    testWidgets('Mine shows hours and commitments; a card opens the event', (
      tester,
    ) async {
      final service = _FakeEvents(
        [_event(myRsvp: 'going')],
        mine: MyCommitments(
          events: [_event(myRsvp: 'going')],
          shifts: [
            const VolunteerShiftWithEvent(
              id: 10,
              roleName: 'Greeter',
              eventId: 1,
              eventTitle: 'Alumnae Fall Social',
            ).shift,
          ],
          attendedCount: 2,
          volunteerHours: 3.5,
        ),
      );
      await _pumpScreen(tester, service);
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('events attended'), findsOneWidget);
      expect(find.text('Greeter'), findsOneWidget);

      await tester.tap(find.text('Greeter'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rsvp')), findsOneWidget);
    });
  });

  group('saving events', () {
    testWidgets('the star on a list card saves and shows the Saved chip', (
      tester,
    ) async {
      final service = _FakeEvents([_event()]);
      await _pumpScreen(tester, service);
      expect(find.text('Saved'), findsNothing);

      await tester.tap(find.byKey(const Key('favorite-1')));
      await tester.pumpAndSettle();
      expect(service.calls, contains('favorite 1 true'));
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byKey(const Key('favorite-1')));
      await tester.pumpAndSettle();
      expect(service.calls, contains('favorite 1 false'));
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('Mine lists saved events', (tester) async {
      final service = _FakeEvents(
        [_event(isFavorite: true)],
        mine: MyCommitments(
          favorites: [_event(title: 'Saved social', isFavorite: true)],
        ),
      );
      await _pumpScreen(tester, service);
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('Saved events'), findsOneWidget);
      expect(find.text('Saved social'), findsOneWidget);
      expect(
        find.text(
          'Nothing yet. Find something under Upcoming and tap '
          'Going.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the star on the event page saves it', (tester) async {
      final service = _FakeEvents([_event()]);
      await _pumpDetail(tester, service);
      expect(find.byKey(const Key('saved-chip')), findsNothing);

      await tester.tap(find.byKey(const Key('favorite')));
      await tester.pumpAndSettle();
      expect(service.calls, contains('favorite 1 true'));
      expect(find.byKey(const Key('saved-chip')), findsOneWidget);
      expect(service.calls.where((c) => c.startsWith('rsvp')), isEmpty);
    });

    test('MyCommitments reads favorites', () {
      final mine = MyCommitments.fromJson({
        'events': [],
        'favorites': [
          {
            'id': 4,
            'title': 'Saved',
            'starts_at': '2026-10-09T18:00:00Z',
            'is_favorite': true,
          },
        ],
        'shifts': [],
      });
      expect(mine.favorites.single.title, 'Saved');
      expect(mine.favorites.single.isFavorite, isTrue);
      expect(mine.favorites.single.isMine, isTrue);
    });
  });

  group('EventDetailScreen', () {
    testWidgets('RSVP and shift sign-up call the service', (tester) async {
      final service = _FakeEvents([
        _event(shifts: [_shift()]),
      ]);
      await _pumpDetail(tester, service);
      expect(find.byKey(const Key('organizer-menu')), findsNothing);

      await tester.tap(find.text('Maybe'));
      await tester.pumpAndSettle();
      expect(service.calls, contains('rsvp 1 maybe'));

      await tester.tap(find.byKey(const Key('claim-10')));
      await tester.pumpAndSettle();
      expect(service.calls, contains('claim 1 10'));
      expect(find.byKey(const Key('release-10')), findsOneWidget);
      expect(find.textContaining('1 of 2 open'), findsOneWidget);

      await tester.tap(find.byKey(const Key('release-10')));
      await tester.pumpAndSettle();
      expect(service.calls, contains('release 1 10'));
      expect(find.byKey(const Key('claim-10')), findsOneWidget);
    });

    testWidgets('cancelled events close sign-ups', (tester) async {
      final service = _FakeEvents([
        _event(isCancelled: true, shifts: [_shift()]),
      ]);
      await _pumpDetail(tester, service);
      expect(find.text('This event was cancelled.'), findsOneWidget);
      expect(find.byKey(const Key('claim-10')), findsNothing);
      await tester.tap(find.text('Maybe'));
      await tester.pumpAndSettle();
      expect(service.calls.where((c) => c.startsWith('rsvp')), isEmpty);
    });

    testWidgets('organizers add a shift from the form', (tester) async {
      final service = _FakeEvents([_event(canManage: true)]);
      await _pumpDetail(tester, service);
      expect(find.byKey(const Key('organizer-menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-shift')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('shift-role')), 'Greeter');
      await tester.enterText(find.byKey(const Key('shift-slots')), '3');
      await tester.tap(find.byKey(const Key('shift-save')));
      await tester.pumpAndSettle();

      expect(service.calls, contains('shift 1 Greeter x3'));
      expect(find.text('Volunteer shifts'), findsOneWidget);
    });
  });

  group('volunteer roles', () {
    test('User and AlumniProfile read volunteer_roles', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'alice',
        'volunteer_roles': ['host', 'mentor'],
      });
      expect(user.volunteerRoles, ['host', 'mentor']);
      expect(
        User.fromJson({'id': 1, 'username': 'alice'}).volunteerRoles,
        isEmpty,
      );
      final profile = AlumniProfile.fromJson({
        'van_id': 1,
        'first_name': 'Alice',
        'last_name': 'A',
        'volunteer_roles': ['phone_bank'],
      });
      expect(profile.volunteerRoles, ['phone_bank']);
    });

    test('directory controller passes the role filter through', () async {
      final service = _RecordingDirectory();
      final controller = AlumniDirectoryController(service: service);
      await controller.setVolunteerRole('mentor');
      expect(service.lastRole, 'mentor');
      expect(controller.volunteerRole, 'mentor');
      controller.dispose();
    });
  });

  group('EventsService wire format', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
      await SharedPreferencesService().init();
    });
    tearDown(() => ApiClient.debugHttpClientOverride = null);

    test('talks to /api/events/', () async {
      final sent = <http.Request>[];
      ApiClient.debugHttpClientOverride = MockClient((request) async {
        sent.add(request);
        if (request.url.path == '/api/events/') {
          return http.Response(jsonEncode([_json(1)]), 200);
        }
        return http.Response(jsonEncode(_json(1, rsvp: 'going')), 200);
      });
      final service = EventsService();
      final events = await service.fetchEvents(when: 'all');
      expect(events.single.title, 'Social');
      expect(events.single.shifts.single.roleName, 'Greeter');
      expect(sent.single.url.query, 'when=all');

      final updated = await service.rsvp(1, 'going');
      expect(updated.myRsvp, 'going');
      expect(sent.last.url.path, '/api/events/1/rsvp/');
      expect(jsonDecode(sent.last.body), {'status': 'going'});
      expect(sent.last.headers['Authorization'], 'Token test-token');
    });
  });
}

Map<String, dynamic> _json(int id, {String? rsvp}) => {
  'id': id,
  'title': 'Social',
  'description': '',
  'starts_at': '2026-10-08T22:00:00Z',
  'ends_at': '2026-10-09T00:00:00Z',
  'location_name': 'Louisville',
  'is_virtual': false,
  'virtual_link': '',
  'is_cancelled': false,
  'capacity': 60,
  'is_demo': true,
  'group': null,
  'created_by': null,
  'going_count': rsvp == null ? 0 : 1,
  'maybe_count': 0,
  'my_rsvp': rsvp,
  'can_manage': false,
  'shifts': [
    {
      'id': 10,
      'role_name': 'Greeter',
      'description': '',
      'starts_at': '2026-10-08T21:30:00Z',
      'ends_at': '2026-10-08T23:00:00Z',
      'slots': 2,
      'claimed': 0,
      'open_slots': 2,
      'my_claim': false,
    },
  ],
  'open_volunteer_slots': 2,
  'my_shift_count': 0,
};

/// Builds a shift as `/api/events/mine/` returns it, with its event.
class VolunteerShiftWithEvent {
  const VolunteerShiftWithEvent({
    required this.id,
    required this.roleName,
    required this.eventId,
    required this.eventTitle,
  });

  final int id;
  final String roleName;
  final int eventId;
  final String eventTitle;

  VolunteerShift get shift => VolunteerShift(
    id: id,
    roleName: roleName,
    startsAt: _now.add(const Duration(days: 3)),
    endsAt: _now.add(const Duration(days: 3, hours: 2)),
    slots: 1,
    claimed: 1,
    openSlots: 0,
    myClaim: true,
    eventId: eventId,
    eventTitle: eventTitle,
  );
}

class _RecordingDirectory extends AlumniDirectoryService {
  String? lastRole;

  @override
  Future<List<AlumniProfile>> fetchAlumni({
    String? search,
    int? cohortYear,
    String? volunteerRole,
  }) async {
    lastRole = volunteerRole;
    return const [];
  }
}
