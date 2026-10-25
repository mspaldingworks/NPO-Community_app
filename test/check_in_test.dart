import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/events/check_in_screens.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _event = CommunityEvent.fromJson({
  'id': 5,
  'title': 'Fall Social',
  'description': '',
  'starts_at': '2026-10-25T22:00:00Z',
  'ends_at': '2026-10-26T00:00:00Z',
  'location_name': 'Louisville',
  'is_virtual': false,
  'virtual_link': '',
  'is_cancelled': false,
  'capacity': null,
  'is_demo': false,
  'group': null,
  'created_by': null,
  'going_count': 2,
  'maybe_count': 0,
  'my_rsvp': null,
  'can_manage': true,
  'shifts': [],
});

Map<String, dynamic> _row(
  int id,
  String name, {
  bool attended = false,
  String? status = 'going',
  bool walkIn = false,
}) => {
  'id': id,
  'username': name.toLowerCase(),
  'display_name': name,
  'program_year': 2019,
  'rsvp_status': status,
  'status': status,
  'attended': attended,
  'checked_in_at': attended ? '2026-10-25T22:42:00Z' : null,
  'checked_in_by': attended ? 'Dana' : null,
  'check_in_method': attended ? 'scan' : '',
  'walk_in': walkIn,
  'shifts': <String>[],
};

class _Fake extends EventsService {
  final calls = <String>[];
  final roster = [_row(1, 'Alice'), _row(2, 'Bob', attended: true)];

  @override
  Future<List<RosterRow>> fetchRoster(int id) async => [
    for (final r in roster) RosterRow.fromJson(r),
  ];

  @override
  Future<List<RosterRow>> searchMembers(int eventId, String query) async {
    calls.add('search $query');
    return [RosterRow.fromJson(_row(3, 'Carol', status: null))];
  }

  @override
  Future<List<RosterRow>> checkIn(
    int id,
    int accountId, {
    bool attended = true,
  }) async {
    calls.add('check-in $accountId $attended');
    return fetchRoster(id);
  }

  @override
  Future<EventLists> fetchLists(int eventId) async => EventLists.fromJson({
    'labels': {
      'registered': 'Registered',
      'attended': 'Attended',
      'no_shows': 'No-shows',
      'walk_ins': 'Walk-ins',
    },
    'counts': {'registered': 2, 'attended': 1, 'no_shows': 1, 'walk_ins': 0},
    'lists': {
      'registered': [_row(1, 'Alice'), _row(2, 'Bob', attended: true)],
      'attended': [
        {..._row(2, 'Bob', attended: true), 'email': 'bob@example.org'},
      ],
      'no_shows': [_row(1, 'Alice')],
      'walk_ins': [],
    },
  });

  @override
  Future<String> exportList(int eventId, String list) async {
    calls.add('export $list');
    return 'display_name\nBob\n';
  }

  @override
  Future<String> fetchMyCode({bool reset = false}) async =>
      reset ? 'EMKY1:7.new:sig' : 'EMKY1:7.abc:sig';
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('service', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
      await SharedPreferencesService().init();
    });
    tearDown(() => ApiClient.debugHttpClientOverride = null);

    test('talks to the check-in endpoints', () async {
      final sent = <http.Request>[];
      ApiClient.debugHttpClientOverride = MockClient((request) async {
        sent.add(request);
        final path = request.url.path;
        if (path.endsWith('.csv')) {
          return http.Response.bytes(
            utf8.encode('display_name,email\nBob,bob@example.org\n'),
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          );
        }
        if (path == '/api/events/my-code/') {
          return http.Response(jsonEncode({'code': 'EMKY1:7.abc:sig'}), 200);
        }
        if (path.endsWith('/scan/')) {
          return http.Response(
            jsonEncode({
              'attendee': {
                'id': 7,
                'display_name': 'Bob',
                'profile_pic': null,
                'program_year': 2019,
              },
              'already_checked_in': false,
              'walk_in': true,
              'attended': 12,
            }),
            200,
          );
        }
        return http.Response(jsonEncode([_row(3, 'Carol')]), 200);
      });
      final service = EventsService();

      expect(await service.fetchMyCode(), 'EMKY1:7.abc:sig');
      expect(sent.last.method, 'GET');
      await service.fetchMyCode(reset: true);
      expect(sent.last.method, 'POST');

      final scan = await service.scanCheckIn(5, 'EMKY1:7.abc:sig');
      expect(sent.last.url.path, '/api/events/5/check-in/scan/');
      expect(jsonDecode(sent.last.body), {'code': 'EMKY1:7.abc:sig'});
      expect(
        (scan.displayName, scan.walkIn, scan.attendedCount),
        ('Bob', true, 12),
      );

      await service.searchMembers(5, 'car ol');
      expect(sent.last.url.query, 'q=car+ol');

      final csv = await service.exportList(5, 'attended');
      expect(sent.last.url.path, '/api/events/5/lists/attended.csv');
      expect(sent.last.headers['Authorization'], 'Token test-token');
      expect(csv, startsWith('display_name,email'));
    });

    test('a check-in reads naturally', () {
      final row = RosterRow.fromJson(_row(2, 'Bob', attended: true));
      expect(row.checkInLine, startsWith('Checked in '));
      expect(row.checkInLine, endsWith('· scanned by Dana'));
      final walkIn = RosterRow.fromJson(
        _row(3, 'Carol', attended: true, walkIn: true),
      );
      expect(walkIn.checkInLine, endsWith('· walk-in'));
    });
  });

  testWidgets('my check-in code is a QR of the signed code', (tester) async {
    await _pump(tester, MyCheckInCodeScreen(service: _Fake(), name: 'Alice'));
    final qr = tester.widget<QrImageView>(
      find.byKey(const Key('my-check-in-qr')),
    );
    expect(qr, isNotNull);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('organizers check people in by hand, walk-ins too', (
    tester,
  ) async {
    final service = _Fake();
    await _pump(tester, EventCheckInScreen(event: _event, service: service));

    expect(find.text('2 RSVPed · 1 checked in'), findsOneWidget);
    expect(find.textContaining('scanned by Dana'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(service.calls, ['check-in 1 true']);

    await tester.enterText(find.byKey(const Key('check-in-search')), 'car');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.calls.last, 'search car');
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('No RSVP'), findsOneWidget);
  });

  testWidgets('event lists with counts and export', (tester) async {
    final service = _Fake();
    await _pump(tester, EventCheckInScreen(event: _event, service: service));
    await tester.tap(find.byKey(const Key('tab-lists')));
    await tester.pumpAndSettle();

    expect(find.text('Attended 1'), findsOneWidget);
    expect(find.text('No-shows 1'), findsOneWidget);
    expect(find.textContaining('bob@example.org'), findsOneWidget);

    await tester.tap(find.byKey(const Key('list-no_shows')));
    await tester.pumpAndSettle();
    expect(find.text('No-shows (1)'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('export-list')));
    await tester.pumpAndSettle();
    expect(service.calls, contains('export no_shows'));
  });
}
