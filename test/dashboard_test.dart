// Home: one Events tile (the website-style rectangle), which lights up only
// when the member has an event of her own this week; no Replies card; the
// change-photo and Messages buttons sit beside the avatar, not on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/pages/dashboard/dashboard_screen.dart';
import 'package:npo_community/widgets/emerge/emerge_components.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 5, 12);

CommunityEvent _event({
  required int id,
  String title = 'Event',
  Duration startsIn = const Duration(days: 2),
  String? myRsvp,
  int myShiftCount = 0,
  bool isFavorite = false,
  bool isCancelled = false,
}) => CommunityEvent(
  id: id,
  title: title,
  startsAt: _now.add(startsIn),
  endsAt: _now.add(startsIn).add(const Duration(hours: 2)),
  myRsvp: myRsvp,
  myShiftCount: myShiftCount,
  isFavorite: isFavorite,
  isCancelled: isCancelled,
);

class _FakeEvents extends EventsService {
  _FakeEvents(this.events);

  final List<CommunityEvent> events;

  @override
  Future<List<CommunityEvent>> fetchEvents({String when = 'upcoming'}) async =>
      events;
}

Future<HomeAlertService> _pump(
  WidgetTester tester,
  List<CommunityEvent> events,
) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService().init();
  AuthService().debugSetCurrentUser(
    User(id: 1, username: 'ava', email: 'ava@test.dev'),
  );
  final alerts = HomeAlertService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: AuthService()),
        ChangeNotifierProvider<HomeAlertService>.value(value: alerts),
      ],
      child: MaterialApp(
        home: DashboardScreen(
          eventsService: _FakeEvents(events),
          now: () => _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return alerts;
}

EmergeActionTile _eventsTile(WidgetTester tester) =>
    tester.widget<EmergeActionTile>(find.byKey(const Key('events-tile')));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('myEventsSoon', () {
    test('keeps going, volunteering and saved events within the week', () {
      final picked = myEventsSoon([
        _event(id: 1, myRsvp: 'going', startsIn: const Duration(days: 6)),
        _event(id: 2, myShiftCount: 1, startsIn: const Duration(days: 1)),
        _event(id: 3, isFavorite: true, startsIn: const Duration(hours: 3)),
        _event(id: 4, myRsvp: 'maybe'),
        _event(id: 5),
        _event(id: 6, myRsvp: 'going', startsIn: const Duration(days: 8)),
        _event(id: 7, myRsvp: 'going', startsIn: const Duration(days: -1)),
        _event(id: 8, isFavorite: true, isCancelled: true),
      ], _now);
      expect(picked.map((e) => e.id), [3, 2, 1]);
    });
  });

  group('DashboardScreen', () {
    testWidgets('has one Events tile and no Replies card', (tester) async {
      await _pump(tester, [_event(id: 1)]);
      expect(find.byKey(const Key('events-tile')), findsOneWidget);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('CALENDAR'), findsNothing);
      expect(find.textContaining('events this week'), findsNothing);
      expect(find.textContaining('repl'), findsNothing);
      expect(find.byKey(const Key('ballot-tile')), findsOneWidget);
    });

    testWidgets('the tile stays plain when nothing is hers this week', (
      tester,
    ) async {
      final alerts = await _pump(tester, [
        _event(id: 1, title: 'Someone else\'s'),
        _event(id: 2, myRsvp: 'maybe'),
        _event(id: 3, myRsvp: 'going', startsIn: const Duration(days: 10)),
      ]);
      expect(_eventsTile(tester).highlighted, isFalse);
      expect(_eventsTile(tester).badge, isNull);
      expect(alerts.hasAlerts, isFalse);
      expect(find.byKey(const Key('events-soon-line')), findsNothing);
    });

    testWidgets('the tile glows with a count for going, shift or saved', (
      tester,
    ) async {
      final alerts = await _pump(tester, [
        _event(id: 1, title: 'Fall Social', isFavorite: true),
        _event(id: 2, myShiftCount: 1, startsIn: const Duration(days: 4)),
        _event(id: 3, myRsvp: 'maybe'),
      ]);
      expect(_eventsTile(tester).highlighted, isTrue);
      expect(_eventsTile(tester).badge, '2');
      expect(alerts.hasAlerts, isTrue);
      expect(find.text('2 of your events are coming up this week.'), findsOne);
    });

    testWidgets('photo and Messages buttons sit to the right of the avatar', (
      tester,
    ) async {
      await _pump(tester, const []);
      final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
      final photo = tester.getRect(find.byKey(const Key('home-change-photo')));
      final messages = tester.getRect(find.byKey(const Key('home-messages')));
      expect(photo.left, greaterThan(avatar.right));
      expect(messages.left, greaterThan(photo.right));
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });
  });
}
