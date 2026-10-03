import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/group_console/group_console_screen.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';

class _FakeConsole extends GroupConsoleService {
  _FakeConsole({required this.canManage, this.canAppoint = false}) : super(1);

  final bool canManage;
  final bool canAppoint;
  final calls = <String>[];
  var votes = <int>[];

  @override
  Future<GroupConsoleOverview> fetchOverview() async => GroupConsoleOverview(
    groupName: 'Emerge KY Statewide',
    canManage: canManage,
    canAppoint: canAppoint,
    welcomeMessage: 'Welcome, alumnae!',
    rules: 'Be kind.',
    isLocked: false,
    admins: const [GroupAdmin(id: 3, name: 'Alice')],
  );

  @override
  Future<List<GroupAnnouncement>> fetchAnnouncements() async => const [
    GroupAnnouncement(id: 1, title: 'Kickoff', body: 'Join us', isPinned: true),
  ];

  @override
  Future<List<GroupEvent>> fetchEvents() async => [
    GroupEvent(id: 1, title: 'Canvass', startsAt: DateTime(2026, 10, 10, 10)),
  ];

  @override
  Future<List<GroupPoll>> fetchPolls() async => [
    GroupPoll(
      id: 5,
      question: 'Meeting night?',
      allowMultiple: false,
      isAnonymous: true,
      isOpen: true,
      totalVoters: votes.isEmpty ? 0 : 1,
      myVotes: votes,
      options: [
        PollOption(id: 1, text: 'Tue', votes: votes.contains(1) ? 1 : 0),
        PollOption(id: 2, text: 'Wed', votes: votes.contains(2) ? 1 : 0),
      ],
    ),
  ];

  @override
  Future<void> vote(int pollId, List<int> optionIds) async {
    calls.add('vote $pollId $optionIds');
    votes = optionIds;
  }

  @override
  Future<void> postAnnouncement({
    required String title,
    String body = '',
    bool isPinned = false,
  }) async => calls.add('announce $title');
}

Future<void> _pump(WidgetTester tester, GroupConsoleService service) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GroupConsoleScreen(
        groupId: 1,
        groupName: 'Emerge KY Statewide',
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('members read the console and vote', (tester) async {
    final service = _FakeConsole(canManage: false);
    await _pump(tester, service);

    expect(find.text('Welcome, alumnae!'), findsOneWidget);
    expect(find.text('Be kind.'), findsOneWidget);
    expect(find.text('Lock posting'), findsNothing);
    expect(find.text('Add admin'), findsNothing);

    await tester.tap(find.text('Polls'));
    await tester.pumpAndSettle();
    expect(find.text('Close poll'), findsNothing);
    final voteButton = find.widgetWithText(FilledButton, 'Vote');
    expect(tester.widget<FilledButton>(voteButton).onPressed, isNull);
    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();
    await tester.tap(voteButton);
    await tester.pumpAndSettle();
    expect(service.calls, ['vote 5 [2]']);
    expect(find.text('Change vote'), findsOneWidget);
  });

  testWidgets('managers can lock, announce and close polls', (tester) async {
    final service = _FakeConsole(canManage: true, canAppoint: true);
    await _pump(tester, service);
    expect(find.text('Lock posting'), findsOneWidget);
    expect(find.text('Add admin'), findsOneWidget);

    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Kickoff'), findsOneWidget);
    await tester.tap(find.text('Announce'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('console-title')), 'Gala');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(service.calls, ['announce Gala']);
  });
}
