import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/community/group_feed.dart';
import 'package:npo_community/models/group.dart';
import 'package:npo_community/models/post.dart';
import 'package:npo_community/pages/community/community_screen.dart';
import 'package:npo_community/pages/community/post_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Post _post(int id, String title, DateTime when, {int author = 1}) => Post(
  id: id,
  title: title,
  body: 'body $id',
  author: author,
  authorUsername: 'alice',
  pubDate: when.toUtc().toIso8601String(),
  groupId: 1,
  comments: const [],
);

class _FakeCommunity extends CommunityService {
  _FakeCommunity({required this.groups, required List<Post> posts})
    : posts = [...posts];

  final List<Group> groups;
  List<Post> posts;
  final calls = <String>[];

  @override
  Future<List<Group>> fetchGroups() async => groups;

  @override
  Future<Group> fetchGroupById(int groupId) async =>
      groups.firstWhere((g) => g.id == groupId);

  @override
  Future<List<Post>> fetchPostsForGroup(int groupId, {DateTime? since}) async {
    calls.add('posts $groupId since=${since == null ? 'none' : 'set'}');
    final mine = posts.where((p) => p.groupId == groupId);
    if (since == null) return mine.toList();
    return mine
        .where((p) => DateTime.parse(p.pubDate!).isAfter(since))
        .toList();
  }
}

final _statewide = Group(id: 1, name: 'Emerge KY Statewide', kind: 'statewide');
final _region = Group(id: 2, name: 'Louisville', kind: 'regional');
final _class = Group(id: 3, name: 'Class of 2019', kind: 'cohort');
final _custom = Group(id: 4, name: 'Book club', kind: 'custom');

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  final t0 = DateTime(2026, 10, 5, 12);

  setUp(() async {
    // Avatars and group images read the token from shared preferences.
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
  });

  testWidgets('the Community tab opens on the statewide feed, newest first', (
    tester,
  ) async {
    final service = _FakeCommunity(
      groups: [_region, _statewide, _class, _custom],
      posts: [
        _post(1, 'Welcome, alumnae', t0),
        _post(2, 'Training day recap', t0.add(const Duration(hours: 2))),
      ],
    );
    await _pump(
      tester,
      CommunityScreen(
        service: service,
        userDirectory: () async => [],
        currentUserId: 1,
        pollInterval: const Duration(minutes: 5),
      ),
    );

    expect(find.text('Emerge KY Statewide'), findsOneWidget);
    expect(find.byKey(const Key('group-feed')), findsOneWidget);
    expect(find.text('Training day recap'), findsOneWidget);
    expect(find.text('Welcome, alumnae'), findsOneWidget);
    final recap = tester.getTopLeft(find.text('Training day recap'));
    final welcome = tester.getTopLeft(find.text('Welcome, alumnae'));
    expect(recap.dy, lessThan(welcome.dy));

    // The other groups are one tap away; the statewide one is not repeated.
    expect(find.byKey(const Key('chip-regional')), findsOneWidget);
    expect(find.byKey(const Key('chip-classes')), findsOneWidget);
    expect(find.byKey(const Key('chip-group-4')), findsOneWidget);
    expect(find.byKey(const Key('chip-group-1')), findsNothing);
    expect(find.byTooltip('Add Post'), findsOneWidget);
    expect(service.calls, ['posts 1 since=none']);
  });

  testWidgets('the live feed polls for newer posts and slots them in on top', (
    tester,
  ) async {
    final service = _FakeCommunity(
      groups: [_statewide],
      posts: [_post(1, 'First', t0)],
    );
    await _pump(
      tester,
      CommunityScreen(
        service: service,
        userDirectory: () async => [],
        currentUserId: 1,
        pollInterval: const Duration(seconds: 5),
      ),
    );
    expect(find.text('First'), findsOneWidget);

    service.posts.add(_post(2, 'Breaking', t0.add(const Duration(minutes: 1))));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Breaking'), findsOneWidget);
    expect(service.calls.last, 'posts 1 since=set');
    final breaking = tester.getTopLeft(find.text('Breaking'));
    final first = tester.getTopLeft(find.text('First'));
    expect(breaking.dy, lessThan(first.dy));
  });

  testWidgets('without a statewide group the tab lists groups instead', (
    tester,
  ) async {
    final service = _FakeCommunity(groups: [_region, _custom], posts: const []);
    await _pump(tester, CommunityScreen(service: service));
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Book club'), findsOneWidget);
    expect(find.byKey(const Key('group-feed')), findsNothing);
  });

  testWidgets('a group page still shows its own feed with the console button', (
    tester,
  ) async {
    final service = _FakeCommunity(
      groups: [_statewide],
      posts: [_post(1, 'Hello', t0)],
    );
    await _pump(
      tester,
      PostListScreen(
        groupId: 1,
        groupName: 'Emerge KY Statewide',
        service: service,
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byTooltip('Group info, events and polls'), findsOneWidget);
  });

  testWidgets('an empty feed invites the first post', (tester) async {
    final service = _FakeCommunity(groups: [_statewide], posts: const []);
    await _pump(
      tester,
      GroupFeed(groupId: 1, groupName: 'Statewide', service: service),
    );
    expect(find.text('Be the first to post!'), findsOneWidget);
  });
}
