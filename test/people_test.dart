import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/program_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/people/people_service.dart';
import 'package:npo_community/features/people/people_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _person(List<String> roles) => {
  'id': 4,
  'username': 'alice',
  'display_name': 'Alice',
  'email': 'alice@example.org',
  'program_year': 2018,
  'is_active': true,
  'roles': roles,
  'can_change': true,
};

Map<String, dynamic> _invite({String status = 'open'}) => {
  'id': 9,
  'code': 'K7QF-2MXP',
  'link': 'https://api.example.org/invite/K7QF2MXP/',
  'status': status,
  'name': 'Nia Newbie',
  'email': '',
  'program_year': 2020,
  'roles': ['board_member'],
  'created_by': 'Dana',
  'expires_at': '2026-11-09T12:00:00Z',
  'used_by': null,
};

class _Fake extends PeopleService {
  final calls = <String>[];
  List<String> roles = ['alumni'];

  @override
  Future<List<Person>> search(String query) async => [
    Person.fromJson(_person(roles)),
  ];

  @override
  Future<List<RoleOption>> fetchRoleOptions() async => const [
    RoleOption(key: 'board_member', label: 'Board Member'),
    RoleOption(key: 'moderator', label: 'Moderator'),
  ];

  @override
  Future<Person> setRole(
    int personId,
    String role, {
    required bool grant,
    required String reason,
  }) async {
    calls.add('role $personId $role $grant $reason');
    roles = grant ? [...roles, role] : roles.where((r) => r != role).toList();
    return Person.fromJson(_person(roles));
  }

  @override
  Future<List<Invite>> fetchInvites() async => [Invite.fromJson(_invite())];

  @override
  Future<Invite> createInvite({
    String name = '',
    String email = '',
    int? programYear,
    List<String> roles = const [],
    String note = '',
  }) async {
    calls.add('invite $name $roles');
    return Invite.fromJson(_invite());
  }
}

Future<void> _pump(WidgetTester tester, PeopleService service) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PeopleTab(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
  });
  tearDown(() => ApiClient.debugHttpClientOverride = null);

  test('the service talks to /api/people/ and checks invites', () async {
    final sent = <http.Request>[];
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      sent.add(request);
      if (request.url.path.startsWith('/api/invites/')) {
        return http.Response(
          jsonEncode({'valid': true, 'name': 'Nia', 'program_year': 2020}),
          200,
        );
      }
      return http.Response(jsonEncode(_person(['board_member'])), 200);
    });
    final person = await PeopleService().setRole(
      4,
      'board_member',
      grant: true,
      reason: 'Elected',
    );
    expect(sent.last.url.path, '/api/people/4/roles/');
    expect(jsonDecode(sent.last.body), {
      'role': 'board_member',
      'grant': true,
      'reason': 'Elected',
    });
    expect(person.roles, ['board_member']);

    final check = await ProgramService().checkInvite('k7qf-2mxp');
    expect(sent.last.url.path, '/api/invites/k7qf2mxp/');
    expect((check.valid, check.programYear), (true, 2020));
  });

  testWidgets('staff put a member on the board, with a reason', (tester) async {
    final service = _Fake();
    await _pump(tester, service);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('K7QF-2MXP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('person-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-board_member')));
    await tester.pumpAndSettle();
    expect(find.text('Make Alice a Board Member'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('role-reason')),
      'Elected in October',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(service.calls, ['role 4 board_member true Elected in October']);
    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('role-board_member')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('invite someone and get a link to share', (tester) async {
    final service = _Fake();
    await _pump(tester, service);
    await tester.tap(find.byKey(const Key('invite-someone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite-name')), 'Nia Newbie');
    await tester.tap(find.byKey(const Key('invite-role-board_member')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-invite')));
    await tester.pumpAndSettle();
    expect(service.calls, ['invite Nia Newbie [board_member]']);
    expect(find.byKey(const Key('invite-created')), findsOneWidget);
    expect(
      find.text('https://api.example.org/invite/K7QF2MXP/'),
      findsOneWidget,
    );
    expect(find.text('K7QF-2MXP'), findsWidgets);
  });
}
