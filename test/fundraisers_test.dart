import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/events/event_detail_screen.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/features/moderation/moderation_screen.dart';
import 'package:npo_community/features/moderation/moderation_service.dart';

final _now = DateTime(2026, 10, 5, 12);

const _catalogJson = {
  'mode': 'preview',
  'review_required': true,
  'min_goal_cents': 2500,
  'max_goal_cents': 10000000,
  'not_deductible': 'Contributions are not tax-deductible.',
  'templates': [
    {
      'key': 'house_party',
      'name': 'House party',
      'tagline': 'Host friends at home.',
      'icon': 'home',
      'campaign_type': 'event',
      'needs_date': true,
      'default_goal_cents': 50000,
      'ticket_price_cents': 2500,
      'duration_hours': 2,
      'title': "{host}'s House Party for Emerge Kentucky",
      'description': 'Join {host}.',
    },
    {
      'key': 'birthday',
      'name': 'Birthday fundraiser',
      'tagline': 'Gifts to Emerge instead of presents.',
      'icon': 'cake',
      'campaign_type': 'fundraise',
      'needs_date': false,
      'default_goal_cents': 25000,
      'ticket_price_cents': null,
      'duration_hours': 0,
      'title': "{host}'s Birthday Fundraiser",
      'description': 'For my birthday…',
    },
  ],
};

Fundraiser _fundraiser({
  int id = 1,
  String status = 'live',
  String mode = 'preview',
  String url = '',
  bool canReview = false,
  bool canManage = true,
  int? eventId,
}) => Fundraiser(
  id: id,
  templateKey: 'house_party',
  templateName: 'House party',
  templateIcon: 'home',
  title: "Maddie's House Party for Emerge Kentucky",
  status: status,
  goalCents: 50000,
  raisedCents: 18500,
  donorCount: 6,
  percent: 37,
  ticketPriceCents: 2500,
  startsAt: _now.add(const Duration(days: 21)),
  locationName: 'Louisville',
  givebutterMode: mode,
  givebutterSlug: 'emergeky-house-party-1',
  givebutterUrl: url,
  canManage: canManage,
  canReview: canReview,
  eventId: eventId,
);

class _FakeFundraisers extends FundraisersService {
  _FakeFundraisers({List<Fundraiser> mine = const [], this.pending = const []})
    : mine = [...mine];

  List<Fundraiser> mine;
  List<Fundraiser> pending;
  final calls = <String>[];
  FundraiserDraft? lastDraft;

  @override
  Future<FundraiserCatalog> fetchCatalog() async =>
      FundraiserCatalog.fromJson(_catalogJson);

  @override
  Future<List<Fundraiser>> fetchMine() async => mine;

  @override
  Future<List<Fundraiser>> fetchPending() async => pending;

  @override
  Future<Fundraiser> create(FundraiserDraft draft) async {
    lastDraft = draft;
    calls.add('create ${draft.templateKey} ${draft.goalCents}');
    final created = _fundraiser(id: 9, status: 'pending_review');
    mine = [...mine, created];
    return created;
  }

  @override
  Future<Fundraiser> approve(int id, {String note = ''}) async {
    calls.add('approve $id "$note"');
    pending = pending.where((f) => f.id != id).toList();
    return _fundraiser(id: id, status: 'live');
  }

  @override
  Future<Fundraiser> reject(int id, {String note = ''}) async {
    calls.add('reject $id "$note"');
    pending = pending.where((f) => f.id != id).toList();
    return _fundraiser(id: id, status: 'rejected');
  }

  @override
  Future<Fundraiser> close(int id) async {
    calls.add('close $id');
    return _fundraiser(id: id, status: 'closed');
  }
}

class _FakeEvents extends EventsService {
  _FakeEvents(this.events);

  final List<CommunityEvent> events;

  @override
  Future<List<CommunityEvent>> fetchEvents({String when = 'upcoming'}) async =>
      events;

  @override
  Future<MyCommitments> fetchMine() async => const MyCommitments();

  @override
  Future<CommunityEvent> fetchEvent(int id) async =>
      events.firstWhere((e) => e.id == id);
}

class _QuietModeration extends ModerationService {}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('models', () {
    test('formats dollars and parses a fundraiser', () {
      expect(formatDollars(50000), r'$500');
      expect(formatDollars(123456), r'$1,234.56');
      expect(formatDollars(0), r'$0');
      final f = Fundraiser.fromJson({
        'id': 3,
        'template_key': 'birthday',
        'template': {'name': 'Birthday', 'icon': 'cake'},
        'title': 'Bday',
        'status': 'pending_review',
        'goal_cents': 25000,
        'raised_cents': 0,
        'percent': 0,
        'host': {'id': 1, 'username': 'alice', 'display_name': 'Alice'},
        'givebutter': {'mode': 'preview', 'campaign_id': '', 'url': ''},
        'can_review': true,
      });
      expect(f.isPending, isTrue);
      expect(f.statusLabel, 'Waiting for review');
      expect(f.host!.displayName, 'Alice');
      expect(f.canReview, isTrue);
      expect(_fundraiser(mode: 'live').statusLabel, 'Live');
      expect(_fundraiser().statusLabel, 'Live (preview)');
    });

    test('draft sends what the API expects', () {
      final json = FundraiserDraft(
        templateKey: 'house_party',
        title: 'Party',
        goalCents: 50000,
        startsAt: DateTime.utc(2026, 11, 1, 18),
        virtualLink: 'https://meet.example',
      ).toJson();
      expect(json['template_key'], 'house_party');
      expect(json['goal_cents'], 50000);
      expect(json['starts_at'], '2026-11-01T18:00:00.000Z');
      expect(json['is_virtual'], isTrue);
      expect(json['ends_at'], isNull);
    });

    test('template title fills in the host', () {
      final template = FundraiserCatalog.fromJson(_catalogJson).templates.first;
      expect(
        template.renderTitle(host: 'Maddie'),
        "Maddie's House Party for Emerge Kentucky",
      );
    });
  });

  group('Mine tab', () {
    testWidgets('lists my fundraisers with progress and the preview note', (
      tester,
    ) async {
      final service = _FakeFundraisers(mine: [_fundraiser()]);
      await _pump(
        tester,
        EventsScreen(
          service: _FakeEvents(const []),
          fundraisers: service,
          hostName: 'Maddie',
          now: () => _now,
          candidates: const [],
        ),
      );
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();

      expect(
        find.text("Maddie's House Party for Emerge Kentucky"),
        findsOneWidget,
      );
      expect(find.textContaining(r'$185 of $500'), findsOneWidget);
      expect(find.text('Live (preview)'), findsOneWidget);
      expect(
        find.textContaining('not connected to Givebutter yet'),
        findsOneWidget,
      );
    });

    testWidgets('start a fundraiser: template, form, submit', (tester) async {
      final service = _FakeFundraisers();
      await _pump(
        tester,
        EventsScreen(
          service: _FakeEvents(const []),
          fundraisers: service,
          hostName: 'Maddie',
          now: () => _now,
          candidates: const [],
        ),
      );
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pick a template'), findsOneWidget);

      await tester.tap(find.byKey(const Key('start-fundraiser')));
      await tester.pumpAndSettle();
      expect(find.text('Start a fundraiser'), findsOneWidget);
      await tester.tap(find.byKey(const Key('template-birthday')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('fundraiser-title')))
            .controller!
            .text,
        "Maddie's Birthday Fundraiser",
      );
      expect(find.byKey(const Key('fundraiser-when')), findsNothing);
      await tester.enterText(find.byKey(const Key('fundraiser-goal')), '300');
      await tester.enterText(
        find.byKey(const Key('fundraiser-message')),
        'Emerge changed my life.',
      );
      await tester.tap(find.byKey(const Key('fundraiser-save')));
      await tester.pumpAndSettle();

      expect(service.calls, ['create birthday 30000']);
      expect(service.lastDraft!.message, 'Emerge changed my life.');
      expect(find.text('Waiting for review'), findsOneWidget);
    });

    testWidgets('a dated template insists on a date and the goal range', (
      tester,
    ) async {
      final service = _FakeFundraisers();
      await _pump(
        tester,
        EventsScreen(
          service: _FakeEvents(const []),
          fundraisers: service,
          hostName: 'Maddie',
          now: () => _now,
          candidates: const [],
        ),
      );
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-fundraiser')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template-house_party')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('fundraiser-goal')), '5');
      await tester.tap(find.byKey(const Key('fundraiser-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Goals run from'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('fundraiser-goal')), '500');
      await tester.tap(find.byKey(const Key('fundraiser-save')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a date and time.'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('the sheet closes a fundraiser', (tester) async {
      final service = _FakeFundraisers(mine: [_fundraiser()]);
      await _pump(
        tester,
        EventsScreen(
          service: _FakeEvents(const []),
          fundraisers: service,
          hostName: 'Maddie',
          now: () => _now,
          candidates: const [],
        ),
      );
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fundraiser-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-givebutter')), findsNothing);
      expect(
        find.textContaining('Planned page: givebutter.com/'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('close-fundraiser')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close fundraiser').last);
      await tester.pumpAndSettle();
      expect(service.calls, ['close 1']);
      expect(find.text('Closed'), findsWidgets);
    });
  });

  group('events', () {
    testWidgets('fundraiser events carry a chip and a give block', (
      tester,
    ) async {
      final event = CommunityEvent(
        id: 4,
        title: 'House Party',
        startsAt: _now.add(const Duration(days: 3)),
        fundraiser: const EventFundraiser(
          id: 1,
          status: 'live',
          goalCents: 50000,
          raisedCents: 18500,
          donorCount: 6,
          url: '',
          mode: 'preview',
        ),
      );
      await _pump(
        tester,
        EventsScreen(
          service: _FakeEvents([event]),
          fundraisers: _FakeFundraisers(),
          now: () => _now,
          candidates: const [],
        ),
      );
      expect(find.text('Fundraiser'), findsOneWidget);

      await _pump(
        tester,
        EventDetailScreen(
          eventId: 4,
          service: _FakeEvents([event]),
          now: () => _now,
        ),
      );
      expect(find.byKey(const Key('give-block')), findsOneWidget);
      expect(find.byKey(const Key('give-button')), findsNothing);
      expect(find.textContaining(r'$185 of $500'), findsOneWidget);
    });
  });

  group('Moderation', () {
    testWidgets('reviews pending fundraisers', (tester) async {
      final service = _FakeFundraisers(
        pending: [
          _fundraiser(id: 7, status: 'pending_review', canReview: true),
        ],
      );
      await _pump(
        tester,
        ModerationScreen(service: _QuietModeration(), fundraisers: service),
      );
      await tester.ensureVisible(find.text('Fundraisers'));
      await tester.tap(find.text('Fundraisers'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fundraiser-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('approve-fundraiser')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('review-note')), 'Go!');
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(service.calls, ['approve 7 "Go!"']);
    });
  });
}
