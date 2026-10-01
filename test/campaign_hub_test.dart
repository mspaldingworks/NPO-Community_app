import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_running/api_campaign_repository.dart';
import 'package:npo_community/features/alumni_running/campaign_channel_screen.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_routes.dart';
import 'package:npo_community/features/alumni_running/campaign_repository.dart';
import 'package:npo_community/features/alumni_running/demo_campaign_repository.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_channel.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/features/alumni_running/models/candidate_draft.dart';
import 'package:npo_community/features/alumni_running/widgets/alumni_wins_card.dart';
import 'package:npo_community/models/chat_message.dart';
import 'package:provider/provider.dart';

const _forbidden = ApiClientException('Forbidden', statusCode: 403);

/// Records requests instead of hitting the network.
class RecordingApiClient extends ApiClient {
  RecordingApiClient(this.responses) : super(logRequests: false);

  final Map<String, Object?> responses;
  final List<String> requests = [];
  final List<Map<String, dynamic>> payloads = [];

  @override
  Map<String, String> get authHeaders => const {'Authorization': 'Token t'};

  Object? _respond(String method, String path) {
    requests.add('$method $path');
    final response = responses['$method $path'];
    if (response is ApiClientException) throw response;
    return response;
  }

  @override
  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  }) async => _respond('GET', urlPath);

  @override
  Future<dynamic> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    payloads.add(jsonPayload);
    return _respond('POST', urlPath);
  }

  @override
  Future<dynamic> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    payloads.add(jsonPayload);
    return _respond('PATCH', urlPath);
  }

  @override
  Future<dynamic> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    int expectedStatusCode = 204,
  }) async => _respond('DELETE', urlPath);
}

class FakeCampaignRepository implements CampaignRepository {
  FakeCampaignRepository({
    List<AlumniCandidate>? candidates,
    List<CampaignShift>? shifts,
    this.writes = true,
    this.canManage = false,
  }) : candidates = candidates ?? [_candidate('c1')],
       shifts = shifts ?? [];

  List<AlumniCandidate> candidates;
  List<CampaignShift> shifts;
  final bool writes;
  bool canManage;
  Object? manageError;
  int createCalls = 0;
  final Map<String, String> memberships = {};
  Object? joinError;
  Object? messagesError;
  int joinCalls = 0;

  @override
  bool get supportsWrites => writes;

  @override
  Future<List<AlumniCandidate>> fetchCandidates() async => candidates;

  @override
  Future<bool> fetchCanManageCandidates() async {
    if (manageError != null) throw manageError!;
    return canManage;
  }

  @override
  Future<AlumniCandidate> createCandidate(CandidateDraft draft) async {
    createCalls++;
    if (manageError != null) throw manageError!;
    final created = _fromDraft('new-${candidates.length + 1}', draft);
    candidates = [...candidates, created];
    return created;
  }

  @override
  Future<AlumniCandidate> updateCandidate(
    String id,
    CandidateDraft draft,
  ) async {
    if (manageError != null) throw manageError!;
    final updated = _fromDraft(id, draft);
    candidates = [for (final c in candidates) c.id == id ? updated : c];
    return updated;
  }

  @override
  Future<void> deleteCandidate(String id) async {
    if (manageError != null) throw manageError!;
    candidates = [
      for (final c in candidates)
        if (c.id != id) c,
    ];
  }

  static AlumniCandidate _fromDraft(String id, CandidateDraft d) =>
      AlumniCandidate(
        id: id,
        name: d.name,
        office: d.office,
        electionName: d.electionName,
        electionDate: d.electionDate,
        status: d.status,
        bio: d.bio,
        vanId: d.vanId,
        campaignUrl: d.campaignUrl,
        donateUrl: d.donateUrl,
        volunteerUrl: d.volunteerUrl,
        infoUrl: d.infoUrl,
      );

  @override
  Future<List<CampaignChannelMembership>> fetchMyChannels() async => [
    for (final e in memberships.entries)
      CampaignChannelMembership(candidateId: e.key, channelId: e.value),
  ];

  @override
  Future<CampaignChannelMembership> joinChannel(String candidateId) async {
    joinCalls++;
    if (joinError != null) throw joinError!;
    memberships[candidateId] = 'ch-$candidateId';
    return CampaignChannelMembership(
      candidateId: candidateId,
      channelId: 'ch-$candidateId',
    );
  }

  @override
  Future<void> leaveChannel(String candidateId) async {
    memberships.remove(candidateId);
  }

  @override
  Future<List<ChatMessage>> fetchChannelMessages(String channelId) async {
    if (messagesError != null) throw messagesError!;
    return [_message('Hello supporters')];
  }

  @override
  Future<ChatMessage> sendChannelMessage(String channelId, String content) =>
      Future.value(_message(content));

  @override
  Stream<void> watchChannel(String channelId) => const Stream.empty();

  @override
  void unwatchChannel(String channelId) {}

  @override
  Future<List<CampaignShift>> fetchShifts(String candidateId) async =>
      shifts.where((s) => s.candidateId == candidateId).toList();

  @override
  Future<List<CampaignShift>> fetchMyShifts() async =>
      shifts.where((s) => s.signedUp).toList();

  @override
  Future<CampaignShift> signUpForShift(CampaignShift shift) async =>
      _update(shift.copyWith(remaining: shift.remaining! - 1, signedUp: true));

  @override
  Future<CampaignShift> cancelShift(CampaignShift shift) async =>
      _update(shift.copyWith(remaining: shift.remaining! + 1, signedUp: false));

  CampaignShift _update(CampaignShift updated) {
    shifts = [for (final s in shifts) s.id == updated.id ? updated : s];
    return updated;
  }
}

AlumniCandidate _candidate(
  String id, {
  CandidateRaceStatus status = CandidateRaceStatus.running,
  Uri? campaignUrl,
  Uri? donateUrl,
  Uri? volunteerUrl,
  int? vanId,
}) => AlumniCandidate(
  id: id,
  name: 'Test Candidate $id',
  office: 'Test Office',
  status: status,
  campaignUrl: campaignUrl,
  donateUrl: donateUrl,
  volunteerUrl: volunteerUrl,
  vanId: vanId,
);

ChatMessage _message(String content) => ChatMessage(
  id: content.hashCode,
  sender: MessageUser(id: 1, username: 'alum'),
  recipient: MessageUser(id: 0, username: 'channel'),
  content: content,
  timestamp: DateTime(2026, 10, 1),
  isRead: true,
);

CampaignShift _shift({int remaining = 3, bool signedUp = false}) =>
    CampaignShift(
      id: 's1',
      candidateId: 'c1',
      kind: CampaignShiftKind.canvass,
      startsAt: DateTime(2026, 10, 10, 10),
      capacity: 10,
      remaining: remaining,
      signedUp: signedUp,
    );

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const Key('save-candidate'));
  await tester.scrollUntilVisible(
    save,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(save);
}

Widget _app(CampaignHubController hub, String location) =>
    ChangeNotifierProvider.value(
      value: hub,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: location,
          routes: [
            campaignHubRoute(),
            GoRoute(
              path: '/directory',
              builder: (_, _) => const Text('directory'),
            ),
          ],
        ),
      ),
    );

void main() {
  group('AlumniCandidate.fromJson', () {
    final media = Uri.parse('https://api.example.org');

    test('parses all fields', () {
      final c = AlumniCandidate.fromJson({
        'id': 7,
        'name': 'Pat Example',
        'office': 'City Council',
        'election_name': 'General',
        'election_date': '2026-11-03',
        'status': 'won_primary',
        'bio': 'Bio',
        'van_id': '42',
        'campaign_url': 'https://pat.example',
        'donate_url': 'https://pat.example/donate',
        'volunteer_url': 'https://pat.example/volunteer',
        'info_url': 'https://info.example/pat',
        'headshot_url': '/media/pat.jpg',
        'win_post': {'group_id': 3, 'post_id': 9},
      }, mediaOrigin: media);
      expect(c.id, '7');
      expect(c.vanId, 42);
      expect(c.status, CandidateRaceStatus.wonPrimary);
      expect(c.status.isWin, isTrue);
      expect(c.electionDate, DateTime(2026, 11, 3));
      expect(c.donateUrl.toString(), 'https://pat.example/donate');
      expect(c.headshotUrl.toString(), 'https://api.example.org/media/pat.jpg');
      expect(c.winPost!.route, '/community/group/3/post/9');
    });

    test('missing optional URLs stay null and unsafe URLs are dropped', () {
      final c = AlumniCandidate.fromJson({
        'id': 'a',
        'name': 'Pat',
        'campaign_url': '',
        'donate_url': 'http://insecure.example',
        'volunteer_url': 'javascript:alert(1)',
        'headshot_url': 'https://tracker.example/pat.jpg',
      }, mediaOrigin: media);
      expect(c.campaignUrl, isNull);
      expect(c.donateUrl, isNull);
      expect(c.volunteerUrl, isNull);
      expect(c.infoUrl, isNull);
      expect(c.headshotUrl, isNull);
      expect(c.vanId, isNull);
      expect(c.electionDate, isNull);
      expect(c.primaryUrl, isNull);
    });

    test('headshots are ignored without a media origin', () {
      final c = AlumniCandidate.fromJson({
        'id': 1,
        'name': 'Pat',
        'headshot_url': '/media/pat.jpg',
      });
      expect(c.headshotUrl, isNull);
    });

    test('unknown status is never a win', () {
      final c = AlumniCandidate.fromJson({
        'id': 1,
        'name': 'Pat',
        'status': 'recount_pending',
      });
      expect(c.status, CandidateRaceStatus.unknown);
      expect(c.status.isWin, isFalse);
      expect(c.status.label, 'Running');
    });

    test('rejects entries without id or name', () {
      expect(
        () => AlumniCandidate.fromJson({'name': 'Pat'}),
        throwsFormatException,
      );
      expect(() => AlumniCandidate.fromJson({'id': 1}), throwsFormatException);
    });

    test('election countdown counts whole days', () {
      final c = AlumniCandidate(
        id: '1',
        name: 'Pat',
        office: 'Office',
        electionDate: DateTime(2026, 11, 3),
      );
      expect(c.daysUntilElection(DateTime(2026, 10, 1, 23)), 33);
      expect(c.daysUntilElection(DateTime(2026, 11, 4)), -1);
    });
  });

  test('CampaignShift parses kind and capacity', () {
    final s = CampaignShift.fromJson({
      'id': 5,
      'candidate_id': 'c1',
      'kind': 'phone-bank',
      'starts_at': '2026-10-10T18:00:00Z',
      'capacity': 10,
      'remaining': 0,
      'signed_up': false,
    });
    expect(s.kind, CampaignShiftKind.phoneBank);
    expect(s.isFull, isTrue);
  });

  group('ApiCampaignRepository', () {
    test('follows the documented contract', () async {
      final client = RecordingApiClient({
        'GET /api/campaigns/candidates/': {
          'results': [
            {'id': 1, 'name': 'Pat', 'office': 'Council'},
            {'name': 'missing id is skipped'},
          ],
        },
        'GET /api/campaigns/channels/': [
          {'candidate_id': 1, 'channel_id': 'opaque-1'},
        ],
        'POST /api/campaigns/candidates/1/channel/join/': _forbidden,
        'GET /api/campaigns/candidates/1/shifts/': [
          {'id': 's1', 'kind': 'canvass', 'starts_at': '2026-10-10T10:00:00Z'},
        ],
      });
      final repo = ApiCampaignRepository(
        client: client,
        mediaOrigin: Uri.parse('https://api.example.org'),
      );

      final candidates = await repo.fetchCandidates();
      expect(candidates.single.name, 'Pat');
      expect((await repo.fetchMyChannels()).single.channelId, 'opaque-1');
      final shifts = await repo.fetchShifts('1');
      expect(shifts.single.candidateId, '1');
      await expectLater(
        repo.joinChannel('1'),
        throwsA(
          isA<ApiClientException>().having((e) => e.isForbidden, '403', true),
        ),
      );
      expect(client.logRequests, isFalse);
    });
  });

  group('ApiCampaignRepository candidate management', () {
    final media = Uri.parse('https://api.example.org');

    test('reads the permission flag and fails closed', () async {
      final granted = ApiCampaignRepository(
        client: RecordingApiClient({
          'GET /api/campaigns/permissions/': {'can_manage_candidates': true},
        }),
        mediaOrigin: media,
      );
      expect(await granted.fetchCanManageCandidates(), isTrue);

      final truthyString = ApiCampaignRepository(
        client: RecordingApiClient({
          'GET /api/campaigns/permissions/': {'can_manage_candidates': 'yes'},
        }),
        mediaOrigin: media,
      );
      expect(await truthyString.fetchCanManageCandidates(), isFalse);
    });

    test('creates with POST and updates with PATCH', () async {
      final client = RecordingApiClient({
        'POST /api/campaigns/candidates/': {
          'id': 9,
          'name': 'Pat',
          'office': 'Council',
        },
        'PATCH /api/campaigns/candidates/9/': {
          'id': 9,
          'name': 'Pat',
          'office': 'Council',
          'status': 'won',
        },
      });
      final repo = ApiCampaignRepository(client: client, mediaOrigin: media);
      const draft = CandidateDraft(name: 'Pat', office: 'Council');

      expect((await repo.createCandidate(draft)).id, '9');
      expect((await repo.updateCandidate('9', draft)).status.isWin, isTrue);
      expect(client.requests, [
        'POST /api/campaigns/candidates/',
        'PATCH /api/campaigns/candidates/9/',
      ]);
      expect(client.payloads.first['name'], 'Pat');
      expect(client.payloads.first['status'], 'running');
    });
  });

  group('CandidateDraft', () {
    test('serializes cleared fields as null and dates as ISO days', () {
      final json = CandidateDraft(
        name: 'Pat',
        office: 'Council',
        electionDate: DateTime(2026, 11, 3),
        status: CandidateRaceStatus.wonPrimary,
        campaignUrl: Uri.parse('https://pat.example'),
      ).toJson();
      expect(json['election_date'], '2026-11-03');
      expect(json['status'], 'won_primary');
      expect(json['campaign_url'], 'https://pat.example');
      expect(json.containsKey('donate_url'), isTrue);
      expect(json['donate_url'], isNull);
      expect(json.containsKey('headshot_url'), isFalse);
    });

    test('accepts only absolute https links', () {
      expect(CandidateDraft.parseLink('  '), isNull);
      expect(
        CandidateDraft.parseLink('https://pat.example/x').toString(),
        'https://pat.example/x',
      );
      for (final bad in [
        'http://pat.example',
        'pat.example',
        'javascript:alert(1)',
      ]) {
        expect(
          () => CandidateDraft.parseLink(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('editing an unknown status falls back to running', () {
      final draft = CandidateDraft.fromCandidate(
        _candidate('c1', status: CandidateRaceStatus.unknown),
      );
      expect(draft.status, CandidateRaceStatus.running);
    });
  });

  group('DemoCampaignRepository', () {
    tearDown(() => ApiClient.debugHttpClientOverride = null);

    test('makes no HTTP calls and uses fictional data only', () async {
      var calls = 0;
      ApiClient.debugHttpClientOverride = MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      });
      final repo = DemoCampaignRepository(now: DateTime(2026, 10, 1));
      final candidates = await repo.fetchCandidates();
      await repo.fetchMyChannels();
      await repo.fetchMyShifts();
      for (final c in candidates) {
        await repo.fetchShifts(c.id);
      }
      await repo.fetchChannelMessages('demo-channel-1');

      expect(calls, 0);
      expect(repo.supportsWrites, isFalse);
      for (final c in candidates) {
        expect(c.name, startsWith('Demo Candidate'));
      }
      final names = candidates.map((c) => c.name).join(' ');
      for (final real in [
        'Furman',
        'Olson',
        'Serenity',
        'Donworth',
        'Berg',
        'Parrish-Wright',
      ]) {
        expect(names, isNot(contains(real)));
      }
    });

    test('rejects writes', () async {
      final repo = DemoCampaignRepository();
      ApiClient.debugHttpClientOverride = null;
      expect(
        repo.joinChannel('demo-1'),
        throwsA(isA<CampaignWritesDisabledException>()),
      );
      expect(
        repo.signUpForShift(_shift()),
        throwsA(isA<CampaignWritesDisabledException>()),
      );
      expect(
        repo.createCandidate(const CandidateDraft(name: 'X', office: 'Y')),
        throwsA(isA<CampaignWritesDisabledException>()),
      );
      expect(await repo.fetchCanManageCandidates(), isFalse);
    });
  });

  group('CampaignHubController', () {
    test('join and leave update membership', () async {
      final repo = FakeCampaignRepository();
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      expect(hub.isJoined('c1'), isFalse);

      expect(await hub.join('c1'), isNull);
      expect(hub.isJoined('c1'), isTrue);
      expect(hub.channelIdFor('c1'), 'ch-c1');
      expect(hub.joinedCandidates.single.id, 'c1');

      expect(await hub.leave('c1'), isNull);
      expect(hub.isJoined('c1'), isFalse);
    });

    test('a 403 on join is reported and leaves the user out', () async {
      final repo = FakeCampaignRepository()..joinError = _forbidden;
      final hub = CampaignHubController(repository: repo);
      await hub.load();

      final error = await hub.join('c1');
      expect(error, contains("don't have access"));
      expect(hub.isJoined('c1'), isFalse);
    });

    test('writes are blocked during Role Preview and in demo', () async {
      final repo = FakeCampaignRepository();
      final preview = CampaignHubController(
        repository: repo,
        isPreviewActive: () => true,
      );
      await preview.load();
      expect(await preview.join('c1'), isNotNull);
      expect(repo.joinCalls, 0);

      final demo = CampaignHubController(
        repository: FakeCampaignRepository(writes: false),
      );
      expect(demo.capabilities.writesEnabled, isFalse);
    });

    test('candidate management needs the server grant', () async {
      final hub = CampaignHubController(repository: FakeCampaignRepository());
      await hub.load();
      expect(hub.capabilities.canManageCandidates, isFalse);
      await expectLater(
        hub.saveCandidate(const CandidateDraft(name: 'X', office: 'Y')),
        throwsA(isA<CampaignHubError>()),
      );
      expect(await hub.deleteCandidate('c1'), isNotNull);
      expect(hub.candidateById('c1'), isNotNull);
    });

    test('a failed permission check fails closed', () async {
      final repo = FakeCampaignRepository(canManage: true)
        ..manageError = const ApiClientException('Down', statusCode: 500);
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      expect(hub.status, CampaignHubStatus.loaded);
      expect(hub.capabilities.canManageCandidates, isFalse);
    });

    test('management is off in Role Preview and demo', () async {
      final preview = CampaignHubController(
        repository: FakeCampaignRepository(canManage: true),
        isPreviewActive: () => true,
      );
      await preview.load();
      expect(preview.capabilities.canManageCandidates, isFalse);

      final demo = CampaignHubController(
        repository: FakeCampaignRepository(canManage: true, writes: false),
      );
      await demo.load();
      expect(demo.capabilities.canManageCandidates, isFalse);
    });

    test('staff can add, edit, and remove candidates', () async {
      final repo = FakeCampaignRepository(canManage: true);
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      expect(hub.capabilities.canManageCandidates, isTrue);

      final id = await hub.saveCandidate(
        const CandidateDraft(name: 'New Alum', office: 'Council'),
      );
      expect(hub.candidateById(id)!.name, 'New Alum');

      await hub.saveCandidate(
        const CandidateDraft(
          name: 'New Alum',
          office: 'Council',
          status: CandidateRaceStatus.won,
        ),
        id: id,
      );
      expect(hub.wins.single.id, id);

      expect(await hub.deleteCandidate(id), isNull);
      expect(hub.candidateById(id), isNull);
    });

    test('a 403 on save revokes management controls', () async {
      final repo = FakeCampaignRepository(canManage: true);
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      repo.manageError = _forbidden;
      await expectLater(
        hub.saveCandidate(const CandidateDraft(name: 'X', office: 'Y')),
        throwsA(isA<CampaignHubError>()),
      );
      expect(hub.capabilities.canManageCandidates, isFalse);
    });

    test('session changes revoke management', () async {
      final controller = StreamController<Object?>();
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(canManage: true),
        sessionChanges: controller.stream,
      );
      await hub.load();
      expect(hub.capabilities.canManageCandidates, isTrue);
      controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(hub.capabilities.canManageCandidates, isFalse);
      await controller.close();
    });

    test('shift sign-up updates capacity and cancelling restores it', () async {
      final repo = FakeCampaignRepository(shifts: [_shift(remaining: 3)]);
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      await hub.loadShifts('c1');

      expect(await hub.signUp(hub.shiftsFor('c1')!.single), isNull);
      expect(hub.shiftsFor('c1')!.single.remaining, 2);
      expect(hub.shiftsFor('c1')!.single.signedUp, isTrue);
      expect(hub.myShifts.single.id, 's1');

      expect(await hub.cancel(hub.shiftsFor('c1')!.single), isNull);
      expect(hub.shiftsFor('c1')!.single.remaining, 3);
      expect(hub.myShifts, isEmpty);
    });

    test('wins only include winning statuses', () async {
      final repo = FakeCampaignRepository(
        candidates: [
          _candidate('a'),
          _candidate('b', status: CandidateRaceStatus.wonPrimary),
          _candidate('c', status: CandidateRaceStatus.won),
          _candidate('d', status: CandidateRaceStatus.didNotWin),
          _candidate('e', status: CandidateRaceStatus.unknown),
        ],
      );
      final hub = CampaignHubController(repository: repo);
      await hub.load();
      expect(hub.wins.map((c) => c.id), ['b', 'c']);
    });

    test('session changes clear cached memberships', () async {
      final sessions = StreamController<Object?>();
      final repo = FakeCampaignRepository()..memberships['c1'] = 'ch-c1';
      final hub = CampaignHubController(
        repository: repo,
        sessionChanges: sessions.stream,
      );
      await hub.load();
      expect(hub.isJoined('c1'), isTrue);

      sessions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(hub.isJoined('c1'), isFalse);
      expect(hub.status, CampaignHubStatus.idle);
      await sessions.close();
    });
  });

  group('Candidate detail page', () {
    testWidgets('hides action buttons whose URLs are missing', (tester) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(
          candidates: [
            _candidate('c1', donateUrl: Uri.parse('https://d.example')),
          ],
        ),
      );
      await tester.pumpWidget(_app(hub, '/alumni/running/c1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('action-donate')), findsOneWidget);
      expect(find.byKey(const Key('action-campaign')), findsNothing);
      expect(find.byKey(const Key('action-volunteer')), findsNothing);
      expect(find.byKey(const Key('directory-profile-link')), findsNothing);
      expect(find.byKey(const Key('message-campaign-team')), findsOneWidget);
    });

    testWidgets('shows the directory link only with a VAN ID', (tester) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(
          candidates: [_candidate('c1', vanId: 12)],
        ),
      );
      await tester.pumpWidget(_app(hub, '/alumni/running/c1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('directory-profile-link')), findsOneWidget);
    });

    testWidgets('signing up for a shift updates remaining spots', (
      tester,
    ) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(shifts: [_shift(remaining: 3)]),
      );
      await tester.pumpWidget(_app(hub, '/alumni/running/c1'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 10 spots left'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('signup-shift-s1')));
      await tester.tap(find.byKey(const Key('signup-shift-s1')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 10 spots left'), findsOneWidget);
      expect(find.byKey(const Key('cancel-shift-s1')), findsOneWidget);
    });
  });

  group('Supporter channel', () {
    TextField composer(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('channel-composer')));

    testWidgets('composer is disabled until the user joins', (tester) async {
      final hub = CampaignHubController(repository: FakeCampaignRepository());
      await tester.pumpWidget(_app(hub, '/alumni/running/c1/channel'));
      await tester.pumpAndSettle();

      expect(composer(tester).enabled, isFalse);
      expect(find.byKey(const Key('leave-channel')), findsNothing);

      await tester.tap(find.byKey(const Key('join-channel')));
      await tester.pumpAndSettle();

      expect(composer(tester).enabled, isTrue);
      expect(find.text('Hello supporters'), findsOneWidget);
      expect(find.byKey(const Key('leave-channel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave-channel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-leave-channel')));
      await tester.pumpAndSettle();
      expect(composer(tester).enabled, isFalse);
      expect(find.byKey(const Key('join-channel')), findsOneWidget);
    });

    testWidgets('a 403 loading messages drops membership', (tester) async {
      final repo = FakeCampaignRepository()
        ..memberships['c1'] = 'ch-c1'
        ..messagesError = _forbidden;
      final hub = CampaignHubController(repository: repo);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: hub,
          child: const MaterialApp(
            home: CampaignChannelScreen(candidateId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(hub.isJoined('c1'), isFalse);
      expect(composer(tester).enabled, isFalse);
      expect(find.byKey(const Key('join-channel')), findsOneWidget);
    });

    testWidgets('join stays disabled in demo mode', (tester) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(writes: false),
      );
      await tester.pumpWidget(_app(hub, '/alumni/running/c1/channel'));
      await tester.pumpAndSettle();
      final join = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('join-channel')),
      );
      expect(join.onPressed, isNull);
    });
  });

  group('Wins', () {
    Widget winsApp(CampaignHubController hub) => ChangeNotifierProvider.value(
      value: hub,
      child: const MaterialApp(home: Scaffold(body: AlumniWinsCard())),
    );

    testWidgets('Home card is hidden without wins', (tester) async {
      final hub = CampaignHubController(repository: FakeCampaignRepository());
      await tester.pumpWidget(winsApp(hub));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alumni-wins-card')), findsNothing);
    });

    testWidgets('Home card and Ballot section show winners', (tester) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(
          candidates: [
            _candidate('a'),
            _candidate('b', status: CandidateRaceStatus.won),
          ],
        ),
      );
      await tester.pumpWidget(winsApp(hub));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alumni-wins-card')), findsOneWidget);
      expect(find.text('Test Candidate b'), findsOneWidget);
      expect(find.text('Test Candidate a'), findsNothing);

      await tester.pumpWidget(_app(hub, '/alumni/running'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wins-section')), findsOneWidget);
    });
  });

  group('Candidate editor', () {
    testWidgets('add and edit controls are hidden without the grant', (
      tester,
    ) async {
      final hub = CampaignHubController(repository: FakeCampaignRepository());
      await tester.pumpWidget(_app(hub, '/alumni/running'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-candidate')), findsNothing);

      await tester.pumpWidget(_app(hub, '/alumni/running/c1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-candidate')), findsNothing);
    });

    testWidgets('the editor refuses users without the grant', (tester) async {
      final hub = CampaignHubController(repository: FakeCampaignRepository());
      await tester.pumpWidget(_app(hub, '/alumni/running/new'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editor-not-allowed')), findsOneWidget);
      expect(find.byKey(const Key('save-candidate')), findsNothing);
    });

    testWidgets('staff can add a candidate and land on its page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = FakeCampaignRepository(canManage: true);
      final hub = CampaignHubController(repository: repo);
      await tester.pumpWidget(_app(hub, '/alumni/running'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-candidate')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field-name')), 'New Alum');
      await tester.enterText(find.byKey(const Key('field-office')), 'Council');
      await tester.enterText(
        find.byKey(const Key('field-campaign-url')),
        'http://insecure.example',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(find.text('Enter a full https:// link.'), findsOneWidget);
      expect(repo.createCalls, 0);

      await tester.enterText(
        find.byKey(const Key('field-campaign-url')),
        'https://new-alum.example',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(find.text('New Alum'), findsWidgets);
      expect(find.byKey(const Key('action-campaign')), findsOneWidget);
      expect(find.byKey(const Key('edit-candidate')), findsOneWidget);
    });

    testWidgets('editing prefills the form', (tester) async {
      final hub = CampaignHubController(
        repository: FakeCampaignRepository(canManage: true),
      );
      await tester.pumpWidget(_app(hub, '/alumni/running/c1/edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit candidate'), findsOneWidget);
      expect(find.text('Test Candidate c1'), findsOneWidget);
      expect(find.byKey(const Key('delete-candidate')), findsOneWidget);
    });
  });
}
