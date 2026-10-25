import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/awards/award_admin.dart';
import 'package:npo_community/features/awards/award_widgets.dart';
import 'package:npo_community/features/awards/awards_screen.dart';
import 'package:npo_community/features/awards/awards_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _award(
  String key, {
  int id = 1,
  bool automatic = true,
  int earned = 0,
  Map<String, dynamic>? progress,
  String category = 'showing_up',
  String audience = 'everyone',
  bool eligible = true,
}) => {
  'id': id,
  'key': key,
  'name': key == 'regular' ? 'Regular' : key,
  'description': 'About $key',
  'icon': 'celebration',
  'color': '#197278',
  'category': category,
  'category_label': category == 'special'
      ? 'Special recognition'
      : 'Showing up',
  'automatic': automatic,
  'threshold': automatic ? 5 : null,
  'rule_label': automatic ? 'Events attended' : null,
  'unit': automatic ? 'events' : null,
  'earned': earned,
  'progress': ?progress,
  'how_to_earn': automatic
      ? 'Check in at 5 Emerge Kentucky events.'
      : 'Given by Emerge Kentucky staff.',
  'audience': audience,
  'audience_label': audience,
  'image': null,
  'eligible': eligible,
};

Map<String, dynamic> _grant(
  Map<String, dynamic> award, {
  String citation = '',
}) => {
  'id': award['id'],
  'award': award,
  'citation': citation,
  'automatic': award['automatic'],
  'granted_at': '2026-10-20T14:00:00Z',
  'granted_by': award['automatic'] == true
      ? null
      : {'id': 9, 'username': 'boss', 'display_name': 'Boss'},
};

class _FakeAwards extends AwardsService {
  _FakeAwards({this.catalog = const {}, this.member = const []});

  final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> member;
  final supportCalls = <String>[];
  final created = <Map<String, dynamic>>[];
  Map<String, CandidateSupport> support = {
    'emky-runner': const CandidateSupport(
      seedId: 'emky-runner',
      supporters: 2,
      counts: {'cheering': 2},
    ),
  };

  @override
  Future<AwardCatalog> fetchCatalog({bool includeRetired = false}) async =>
      AwardCatalog.fromJson(catalog);

  @override
  Future<List<AwardGrant>> fetchMemberAwards(int userId) async =>
      AwardGrant.listFromJson(member);

  @override
  Future<Map<String, CandidateSupport>> fetchCandidateSupport() async =>
      support;

  @override
  Future<CandidateSupport> setCandidateSupport(
    String seedId,
    SupportKind kind, {
    required bool active,
  }) async {
    supportCalls.add('$seedId ${kind.key} $active');
    return CandidateSupport(
      seedId: seedId,
      supporters: active ? 3 : 2,
      mine: active ? {kind.key} : const {},
    );
  }

  @override
  Future<AwardOptions> fetchOptions() async => AwardOptions.fromJson({
    'rules': [
      {'key': 'events_attended', 'label': 'Events attended', 'unit': 'events'},
    ],
    'icons': ['star', 'trophy'],
    'categories': [
      {'key': 'special', 'label': 'Special recognition'},
      {'key': 'showing_up', 'label': 'Showing up'},
    ],
    'current_class_year': 2026,
  });

  @override
  Future<Award> createAward(Map<String, dynamic> fields) async {
    created.add(fields);
    return Award.fromJson(_award('new', id: 99));
  }
}

void main() {
  group('service', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
      await SharedPreferencesService().init();
    });
    tearDown(() => ApiClient.debugHttpClientOverride = null);

    test('talks to /api/awards/ and /api/candidates/', () async {
      final sent = <http.Request>[];
      ApiClient.debugHttpClientOverride = MockClient((request) async {
        sent.add(request);
        switch (request.url.path) {
          case '/api/awards/':
            return http.Response(
              jsonEncode({
                'awards': [
                  _award('regular', progress: {'value': 2, 'target': 5}),
                ],
                'mine': [],
              }),
              200,
            );
          case '/api/awards/4/grant/':
            return http.Response(
              jsonEncode([_grant(_award('mentor', id: 4, automatic: false))]),
              201,
            );
          case '/api/awards/grants/7/revoke/':
            return http.Response('', 204);
          default:
            return http.Response(
              jsonEncode({
                'seed_id': 'emky-runner',
                'counts': {'cheering': 0, 'volunteered': 1, 'donated': 0},
                'supporters': 1,
                'mine': ['volunteered'],
              }),
              200,
            );
        }
      });
      final service = AwardsService();

      final catalog = await service.fetchCatalog();
      expect(catalog.awards.single.progress!.fraction, 0.4);
      expect(sent.last.headers['Authorization'], 'Token test-token');

      final grants = await service.grantAward(4, [5, 6], citation: 'Thanks!');
      expect(grants.single.grantedBy, 'Boss');
      expect(jsonDecode(sent.last.body), {
        'account_ids': [5, 6],
        'citation': 'Thanks!',
      });

      await service.revokeGrant(7);
      expect(sent.last.url.path, '/api/awards/grants/7/revoke/');

      final support = await service.setCandidateSupport(
        'emky-runner',
        SupportKind.volunteered,
        active: true,
      );
      expect(sent.last.url.path, '/api/candidates/emky-runner/support/');
      expect(jsonDecode(sent.last.body), {
        'kind': 'volunteered',
        'active': true,
      });
      expect(support.marked(SupportKind.volunteered), isTrue);
    });

    test('uploads artwork as multipart', () async {
      final requests = <http.BaseRequest>[];
      ApiClient.debugHttpClientOverride = MockClient.streaming((
        request,
        body,
      ) async {
        requests.add(request);
        await body.drain<void>();
        final award = _award('mentor', automatic: false)
          ..['image'] = '/media/award_art/mentor.png';
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(award))),
          200,
        );
      });
      final file = File('${Directory.systemTemp.path}/award-art-test.png')
        ..writeAsBytesSync([137, 80, 78, 71]);
      addTearDown(() => file.deleteSync());

      final award = await AwardsService().uploadImage(4, file.path);
      expect(requests.single.url.path, '/api/awards/4/image/');
      expect(requests.single.headers['Authorization'], 'Token test-token');
      expect(award.image, '/media/award_art/mentor.png');
      expect(award.imageUrl, endsWith('/media/award_art/mentor.png'));
    });
  });

  group('members', () {
    testWidgets('the gallery splits alumni awards from class achievements', (
      tester,
    ) async {
      final mentor = _award(
        'mentor',
        id: 2,
        automatic: false,
        earned: 1,
        category: 'special',
        audience: 'alumni',
      );
      final service = _FakeAwards(
        catalog: {
          'awards': [
            _award('regular', progress: {'value': 3, 'target': 5}),
            mentor,
            _award(
              'hello-class',
              id: 3,
              audience: 'current_class',
              eligible: false,
            ),
          ],
          'mine': [_grant(mentor, citation: 'For mentoring the Class of 2026')],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AwardsScreen(
            service: service,
            now: () => DateTime(2026, 10, 25),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alumni tab: alumni awards and shared ones, earned first.
      expect(find.byKey(const Key('gallery-mentor')), findsOneWidget);
      expect(find.byKey(const Key('gallery-regular')), findsOneWidget);
      expect(find.byKey(const Key('gallery-hello-class')), findsNothing);
      expect(find.text('1 of 2 earned'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('gallery-mentor'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('gallery-regular'))).dx,
        ),
      );

      // A tile opens the award's page with how to earn it.
      await tester.tap(find.byKey(const Key('gallery-regular')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('award-detail-regular')), findsOneWidget);
      expect(
        find.text('Check in at 5 Emerge Kentucky events.'),
        findsOneWidget,
      );
      expect(find.text('3 of 5 events'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery-mentor')));
      await tester.pumpAndSettle();
      expect(find.text('“For mentoring the Class of 2026”'), findsOneWidget);
      expect(find.text('You earned this'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Class tab: class achievements and shared ones.
      await tester.tap(find.byKey(const Key('tab-class-achievements')));
      await tester.pumpAndSettle();
      expect(find.text('Class of 2026'), findsOneWidget);
      expect(find.byKey(const Key('gallery-hello-class')), findsOneWidget);
      expect(find.byKey(const Key('gallery-mentor')), findsNothing);
      await tester.tap(find.byKey(const Key('gallery-hello-class')));
      await tester.pumpAndSettle();
      expect(
        find.text('This one is for members of the current class.'),
        findsOneWidget,
      );
    });

    testWidgets('the class opens on its own tab', (tester) async {
      final service = _FakeAwards(
        catalog: {
          'awards': [
            _award('hello-class', audience: 'current_class'),
            _award('mentor', id: 2, audience: 'alumni'),
          ],
          'mine': [],
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: AwardsScreen(service: service, inCurrentClass: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gallery-hello-class')), findsOneWidget);
      expect(find.byKey(const Key('gallery-mentor')), findsNothing);
    });

    testWidgets('a member profile hides the section when they hold none', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAwardsSection(userId: 1, service: _FakeAwards()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-awards')), findsNothing);

      final held = _FakeAwards(member: [_grant(_award('regular'))]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MemberAwardsSection(userId: 2, service: held)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-awards')), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
    });

    testWidgets('Home nudges toward the closest award before the first', (
      tester,
    ) async {
      final service = _FakeAwards(
        catalog: {
          'awards': [
            _award('first-event', id: 1, progress: {'value': 0, 'target': 1}),
            _award('regular', id: 2, progress: {'value': 3, 'target': 5}),
          ],
          'mine': [],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MyAwardsPanel(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Earn your first award'), findsOneWidget);
      expect(
        find.text('Regular: Check in at 5 Emerge Kentucky events.'),
        findsOneWidget,
      );
    });

    testWidgets('Ballot cards record how I am helping', (tester) async {
      final service = _FakeAwards();
      await tester.pumpWidget(
        MaterialApp(
          home: AlumniRunningScreen(
            candidates: const [
              AlumniCandidate(
                seedId: 'emky-runner',
                name: 'Rae Runner',
                office: 'Kentucky House, District 40',
                election: '2026 General Election',
              ),
            ],
            showPhotos: false,
            now: () => DateTime(2026, 10, 25),
            awardsService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 members are backing this campaign'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('support-emky-runner-volunteered')),
      );
      await tester.pumpAndSettle();
      expect(service.supportCalls, ['emky-runner volunteered true']);
      expect(find.text('3 members are backing this campaign'), findsOneWidget);
    });
  });

  group('administrators', () {
    // The editor is a long form; give it room so every field is built.
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1200, 2400);
      view.devicePixelRatio = 1;
    });
    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets('design a new automatic award', (tester) async {
      final service = _FakeAwards(catalog: {'awards': [], 'mine': []});
      await tester.pumpWidget(
        MaterialApp(home: AwardEditorScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('award-name')), 'Day One');
      await tester.tap(find.byKey(const Key('icon-trophy')));
      await tester.tap(find.text('Automatically'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('award-threshold')), '1');
      await tester.tap(find.byKey(const Key('save-award')));
      await tester.pumpAndSettle();

      expect(service.created.single, {
        'name': 'Day One',
        'description': '',
        'icon': 'trophy',
        'color': '#197278',
        'category': 'special',
        'audience': 'everyone',
        'rule': 'events_attended',
        'threshold': 1,
        'how_to_earn': '',
      });
    });

    testWidgets('an automatic award needs a goal', (tester) async {
      final service = _FakeAwards(catalog: {'awards': [], 'mine': []});
      await tester.pumpWidget(
        MaterialApp(home: AwardEditorScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('award-name')), 'Day One');
      await tester.tap(find.text('Automatically'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-award')));
      await tester.pump();
      expect(service.created, isEmpty);
      expect(
        find.text('Automatic awards need a goal of at least 1.'),
        findsOneWidget,
      );
    });
  });
}
