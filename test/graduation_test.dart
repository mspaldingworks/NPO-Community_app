import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/graduation/graduation_screen.dart';
import 'package:npo_community/features/graduation/graduation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _requirements = [
  {
    'id': 1,
    'name': 'Fundraising',
    'description': '',
    'source': 'class_fundraising',
    'source_label': 'Class fundraising (Givebutter)',
    'target': 1000,
    'unit': 'dollars',
    'position': 0,
    'is_active': true,
  },
  {
    'id': 2,
    'name': 'Class sessions',
    'description': 'Attend the class training sessions.',
    'source': 'class_sessions',
    'source_label': 'Class sessions attended',
    'target': 7,
    'unit': 'sessions',
    'position': 10,
    'is_active': true,
  },
];

Map<String, dynamic> _status(
  int id, {
  num automatic = 0,
  num adjustment = 0,
  num target = 7,
  bool met = false,
  bool waived = false,
}) => {
  'requirement_id': id,
  'automatic': automatic,
  'adjustment': adjustment,
  'value': automatic + adjustment,
  'target': target,
  'waived': waived,
  'met': met,
};

Map<String, dynamic> _member(int id, String name, {bool complete = false}) => {
  'id': id,
  'display_name': name,
  'joined': true,
  'met': complete ? 2 : 0,
  'total': 2,
  'complete': complete,
  'requirements': [
    _status(1, automatic: complete ? 1000 : 340, target: 1000, met: complete),
    _status(2, automatic: complete ? 7 : 2, met: complete),
  ],
};

final _overview = {
  'year': 2026,
  'years': [2026, 2025],
  'requirements': _requirements,
  'members': [_member(1, 'Ada', complete: true), _member(2, 'Zoe')],
  'summary': {
    'members': 2,
    'complete': 1,
    'met_by_requirement': {'1': 1, '2': 1},
  },
  'fundraising_sample': true,
  'fundraising_available': true,
};

Map<String, dynamic> _detail({num adjustment = 6, String note = ''}) => {
  ..._member(2, 'Zoe'),
  'requirements': [
    _status(1, automatic: 340, target: 1000),
    {
      ..._status(2, automatic: 2, adjustment: adjustment),
      'note': note,
      'updated_by': note.isEmpty ? null : {'id': 9, 'display_name': 'Staff'},
      'updated_at': note.isEmpty ? null : '2026-10-25T15:00:00Z',
    },
  ],
  'program_year': 2026,
  'requirements_info': _requirements,
  'history': [
    {
      'at': '2026-10-25T15:00:00Z',
      'by': {'id': 9, 'display_name': 'Staff'},
      'notes': 'Class sessions: adjustment +0 → +6. Sessions before the app',
    },
  ],
  'fundraising_sample': true,
  'fundraising_available': true,
};

class _Fake extends GraduationService {
  final edits = <Map<String, dynamic>>[];

  @override
  Future<GraduationOverview> fetchOverview({int? year}) async =>
      GraduationOverview.fromJson(_overview);

  @override
  Future<GradMemberDetail> fetchMember(int memberId) async =>
      GradMemberDetail.fromJson(_detail());

  @override
  Future<GradMemberDetail> editProgress(
    int memberId,
    int requirementId, {
    double? adjustment,
    bool? waived,
    required String note,
  }) async {
    edits.add({
      'member': memberId,
      'requirement': requirementId,
      'adjustment': adjustment,
      'waived': waived,
      'note': note,
    });
    return GradMemberDetail.fromJson(
      _detail(adjustment: adjustment ?? 0, note: note),
    );
  }
}

void main() {
  test('talks to /api/graduation/', () async {
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
    final sent = <http.Request>[];
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      sent.add(request);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode(request.method == 'GET' ? _overview : _detail()),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(() => ApiClient.debugHttpClientOverride = null);

    final service = GraduationService();
    final overview = await service.fetchOverview(year: 2025);
    expect(sent.last.url.toString(), endsWith('/api/graduation/?year=2025'));
    expect(overview.metByRequirement, {1: 1, 2: 1});
    expect(overview.members.first.requirements.first.value, 1000);

    await service.editProgress(2, 2, adjustment: 6, note: 'Before the app');
    expect(sent.last.method, 'PATCH');
    expect(sent.last.url.path, '/api/graduation/members/2/requirements/2/');
    expect(jsonDecode(sent.last.body), {
      'adjustment': 6,
      'note': 'Before the app',
    });
    expect(sent.last.headers['Authorization'], 'Token test-token');
  });

  test('amounts read naturally', () {
    expect(formatAmount(412.5, 'dollars'), r'$412.50');
    expect(formatAmount(7, 'sessions'), '7 sessions');
    expect(formatAmount(3.5, 'hours'), '3.5 hours');
  });

  testWidgets('the class at a glance, filtered and searched', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: GraduationScreen(service: _Fake())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 have met every requirement'), findsOneWidget);
    expect(find.byKey(const Key('graduation-sample')), findsOneWidget);
    expect(find.text('Complete'), findsWidgets);
    expect(find.text('0 of 2 met'), findsOneWidget);
    expect(find.text(r'$340 of $1,000'), findsOneWidget);
    expect(find.text('2 sessions of 7 sessions'), findsOneWidget);

    await tester.tap(find.text('Not done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('graduation-member-1')), findsNothing);
    expect(find.byKey(const Key('graduation-member-2')), findsOneWidget);

    await tester.tap(find.text('Everyone'));
    await tester.enterText(find.byKey(const Key('graduation-search')), 'ad');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('graduation-member-1')), findsOneWidget);
    expect(find.byKey(const Key('graduation-member-2')), findsNothing);
  });

  testWidgets('staff edit a member\'s progress, with a note', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _Fake();
    await tester.pumpWidget(
      MaterialApp(home: GraduationMemberScreen(memberId: 2, service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Counted by the app: 2 sessions · Staff adjustment: +6 sessions',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('adjustment +0 → +6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-progress-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('progress-amount')), '3');
    await tester.tap(find.byKey(const Key('progress-save')));
    await tester.pumpAndSettle();
    expect(find.text('Add a note saying why.'), findsOneWidget);
    expect(service.edits, isEmpty);

    await tester.enterText(
      find.byKey(const Key('progress-note')),
      'Three sessions on paper sign-in',
    );
    await tester.tap(find.byKey(const Key('progress-save')));
    await tester.pumpAndSettle();
    expect(service.edits.single, {
      'member': 2,
      'requirement': 2,
      'adjustment': 3.0,
      'waived': false,
      'note': 'Three sessions on paper sign-in',
    });
    expect(
      find.textContaining('“Three sessions on paper sign-in” (Staff'),
      findsOneWidget,
    );
  });
}
