import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/alumni_running/alumni_candidates.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/events/event_detail_screen.dart';
import 'package:npo_community/features/events/event_form.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/fundraisers/fundraiser_widgets.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an event's page by route when the app's router is around, else by a
/// plain push (demo builds and tests).
void openEvent(BuildContext context, int id, {EventsService? service}) {
  if (GoRouter.maybeOf(context) != null) {
    context.push('/events/$id');
  } else {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(eventId: id, service: service),
      ),
    );
  }
}

/// Something with a date that can sit in the events list: one of ours, or a
/// campaign shift for an alumna on the ballot.
sealed class EventListItem {
  DateTime get startsAt;
}

final class CommunityEventItem extends EventListItem {
  CommunityEventItem(this.event);

  final CommunityEvent event;

  @override
  DateTime get startsAt => event.startsAt;
}

final class CampaignItem extends EventListItem {
  CampaignItem(this.candidate, this.opportunity);

  final AlumniCandidate candidate;
  final VolunteerOpportunity opportunity;

  @override
  DateTime get startsAt => opportunity.startsAt;
}

/// Campaign shifts from the Ballot page that haven't happened yet, soonest
/// first. Empty once Election Day is over.
List<CampaignItem> campaignItems(
  DateTime now, {
  List<AlumniCandidate>? candidates,
}) {
  if (!now.isBefore(alumniCandidatesHideAfter)) return const [];
  final items = [
    for (final candidate in candidates ?? alumniCandidates2026)
      for (final opportunity in candidate.upcomingOpportunities(now))
        CampaignItem(candidate, opportunity),
  ];
  items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return items;
}

/// An event is upcoming until it ends; without an end time it counts as two
/// hours long.
bool isUpcoming(CommunityEvent event, DateTime now) {
  final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 2));
  return end.isAfter(now);
}

final _dayFormat = DateFormat('EEE, MMM d');
final _timeFormat = DateFormat('h:mm a');

String formatWhen(DateTime start, DateTime? end) {
  final day = _dayFormat.format(start);
  if (end == null) return '$day · ${_timeFormat.format(start)}';
  if (isSameDay(start, end)) {
    return '$day · ${_timeFormat.format(start)}–${_timeFormat.format(end)}';
  }
  return '$day ${_timeFormat.format(start)} – ${_dayFormat.format(end)} '
      '${_timeFormat.format(end)}';
}

/// The Events tab: what's coming up (ours and campaign shifts), a month
/// calendar, and what the member has signed up for.
class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    this.service,
    this.fundraisers,
    this.canModerate = false,
    this.hostName = 'You',
    this.classYear,
    this.now,
    this.candidates,
  });

  /// Injected in tests.
  final EventsService? service;
  final FundraisersService? fundraisers;

  /// The signed-in member's name and Emerge class, used to prefill a new
  /// fundraiser's title.
  final String hostName;
  final int? classYear;

  /// Moderators may add statewide events.
  final bool canModerate;

  /// Clock override for tests.
  final DateTime Function()? now;

  /// Ballot candidates override for tests; defaults to this cycle's list.
  final List<AlumniCandidate>? candidates;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsService _service = widget.service ?? EventsService();
  late final FundraisersService _fundraisers =
      widget.fundraisers ?? FundraisersService();
  late Future<List<CommunityEvent>> _events = _service.fetchEvents(when: 'all');
  late Future<MyCommitments> _mine = _service.fetchMine();
  late Future<List<Fundraiser>> _myFundraisers = _fundraisers.fetchMine();

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  Future<void> _reload() async {
    final events = _service.fetchEvents(when: 'all');
    final mine = _service.fetchMine();
    final fundraisers = _fundraisers.fetchMine();
    setState(() {
      _events = events;
      _mine = mine;
      _myFundraisers = fundraisers;
    });
    // Each tab reports its own failure; a refresh must not throw.
    await Future.wait([events, mine, fundraisers].map(_settle));
  }

  static Future<void> _settle(Future<Object?> future) =>
      future.then((_) {}, onError: (Object _) {});

  Future<void> _startFundraiser() async {
    final created = await startFundraiserFlow(
      context,
      service: _fundraisers,
      hostName: widget.hostName,
      classYear: widget.classYear,
    );
    if (created) await _reload();
  }

  Future<void> _openFundraiser(Fundraiser fundraiser) => showFundraiserSheet(
    context,
    fundraiser: fundraiser,
    service: _fundraisers,
    onChanged: _reload,
    onOpenEvent: _open,
  );

  Future<void> _create() async {
    final saved = await showEventForm(
      context,
      title: 'New statewide event',
      onSubmit: (draft) => _service.createEvent(draft),
    );
    if (saved) await _reload();
  }

  void _open(int id) => openEvent(context, id, service: _service);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const TourAnchor(
            name: 'Events Calendar',
            child: Text('Events'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Calendar'),
              Tab(text: 'Mine'),
            ],
          ),
        ),
        floatingActionButton: widget.canModerate
            ? FloatingActionButton.extended(
                key: const Key('new-event'),
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Event'),
              )
            : null,
        body: FutureBuilder<List<CommunityEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? _Message(
                      'Events are unavailable right now.\n${snapshot.error}',
                      onRetry: _reload,
                    )
                  : const Center(child: CircularProgressIndicator());
            }
            final events = snapshot.data!;
            final now = _now;
            final upcoming = <EventListItem>[
              for (final e in events)
                if (isUpcoming(e, now)) CommunityEventItem(e),
              ...campaignItems(now, candidates: widget.candidates),
            ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            return TabBarView(
              children: [
                _UpcomingTab(
                  items: upcoming,
                  canModerate: widget.canModerate,
                  onOpen: _open,
                  onRefresh: _reload,
                ),
                _CalendarTab(
                  items: [
                    for (final e in events) CommunityEventItem(e),
                    ...campaignItems(now, candidates: widget.candidates),
                  ],
                  now: now,
                  canModerate: widget.canModerate,
                  onOpen: _open,
                ),
                _MineTab(
                  future: _mine,
                  fundraisers: _myFundraisers,
                  canModerate: widget.canModerate,
                  onOpen: _open,
                  onRefresh: _reload,
                  onStartFundraiser: _startFundraiser,
                  onOpenFundraiser: _openFundraiser,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UpcomingTab extends StatelessWidget {
  const _UpcomingTab({
    required this.items,
    required this.canModerate,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<EventListItem> items;
  final bool canModerate;
  final void Function(int id) onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? const _Message(
              'Nothing on the calendar yet. Check back soon, or see the '
              'Ballot page for ways to help alumnae running this fall.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                for (final item in items)
                  EventListCard(
                    item: item,
                    showSample: canModerate,
                    onOpen: onOpen,
                  ),
              ],
            ),
    );
  }
}

class _CalendarTab extends StatefulWidget {
  const _CalendarTab({
    required this.items,
    required this.now,
    required this.canModerate,
    required this.onOpen,
  });

  final List<EventListItem> items;
  final DateTime now;
  final bool canModerate;
  final void Function(int id) onOpen;

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab>
    with AutomaticKeepAliveClientMixin {
  late DateTime _focused = widget.now;
  late DateTime _selected = widget.now;

  @override
  bool get wantKeepAlive => true;

  List<EventListItem> _onDay(DateTime day) => [
    for (final item in widget.items)
      if (isSameDay(item.startsAt, day)) item,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = _onDay(_selected);
    return Column(
      children: [
        TableCalendar<EventListItem>(
          firstDay: DateTime(widget.now.year - 1, 1, 1),
          lastDay: DateTime(widget.now.year + 2, 12, 31),
          focusedDay: _focused,
          currentDay: widget.now,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          selectedDayPredicate: (day) => isSameDay(_selected, day),
          onDaySelected: (day, focused) => setState(() {
            _selected = day;
            _focused = focused;
          }),
          onPageChanged: (focused) => _focused = focused,
          eventLoader: _onDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(color: scheme.onSecondaryContainer),
            selectedDecoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selected.isEmpty
              ? _Message('Nothing on ${_dayFormat.format(_selected)}.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    for (final item in selected)
                      EventListCard(
                        item: item,
                        showSample: widget.canModerate,
                        onOpen: widget.onOpen,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MineTab extends StatelessWidget {
  const _MineTab({
    required this.future,
    required this.fundraisers,
    required this.canModerate,
    required this.onOpen,
    required this.onRefresh,
    required this.onStartFundraiser,
    required this.onOpenFundraiser,
  });

  final Future<MyCommitments> future;
  final Future<List<Fundraiser>> fundraisers;
  final bool canModerate;
  final void Function(int id) onOpen;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onStartFundraiser;
  final Future<void> Function(Fundraiser fundraiser) onOpenFundraiser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<MyCommitments>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _Message('${snapshot.error}', onRetry: onRefresh)
              : const Center(child: CircularProgressIndicator());
        }
        final mine = snapshot.data!;
        final hours = mine.volunteerHours == mine.volunteerHours.roundToDouble()
            ? mine.volunteerHours.toStringAsFixed(0)
            : mine.volunteerHours.toStringAsFixed(1);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${mine.attendedCount}',
                          label: mine.attendedCount == 1
                              ? 'event attended'
                              : 'events attended',
                        ),
                      ),
                      Expanded(
                        child: _Stat(value: hours, label: 'volunteer hours'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your fundraisers',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('start-fundraiser'),
                    onPressed: onStartFundraiser,
                    icon: const Icon(Icons.add),
                    label: const Text('Start one'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _FundraisersSection(
                future: fundraisers,
                showSample: canModerate,
                onOpen: onOpenFundraiser,
              ),
              const SizedBox(height: 12),
              Text('Your RSVPs', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              if (mine.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nothing yet. Find something under Upcoming and tap '
                    'Going.',
                  ),
                )
              else
                for (final event in mine.events)
                  EventListCard(
                    item: CommunityEventItem(event),
                    showSample: false,
                    onOpen: onOpen,
                  ),
              const SizedBox(height: 12),
              Text('Your volunteer shifts', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              if (mine.shifts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No shifts claimed yet.'),
                )
              else
                for (final shift in mine.shifts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.volunteer_activism_outlined),
                      title: Text(shift.roleName),
                      subtitle: Text(
                        [
                          if (shift.eventTitle != null) shift.eventTitle!,
                          formatWhen(shift.startsAt, shift.endsAt),
                        ].join('\n'),
                      ),
                      isThreeLine: shift.eventTitle != null,
                      onTap: shift.eventId == null
                          ? null
                          : () => onOpen(shift.eventId!),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// The member's own fundraisers, with a preview note while Givebutter is
/// not connected.
class _FundraisersSection extends StatelessWidget {
  const _FundraisersSection({
    required this.future,
    required this.showSample,
    required this.onOpen,
  });

  final Future<List<Fundraiser>> future;
  final bool showSample;
  final Future<void> Function(Fundraiser fundraiser) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Fundraiser>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: snapshot.hasError
                ? Text('${snapshot.error}')
                : const LinearProgressIndicator(),
          );
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Host a house party, happy hour or birthday fundraiser for '
              'Emerge Kentucky. Pick a template and we set up the page.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.any((f) => f.givebutterMode != 'live'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  previewNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            for (final fundraiser in rows)
              FundraiserCard(
                fundraiser: fundraiser,
                showSample: showSample,
                onTap: () => onOpen(fundraiser),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    children: [
      Text(text, textAlign: TextAlign.center),
      if (onRetry != null)
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
    ],
  );
}

/// One row in an events list: a date block, the title, where and when, and
/// chips for scope and status. Campaign shifts open the campaign's sign-up
/// page; ours open the event page.
class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.item,
    required this.showSample,
    required this.onOpen,
  });

  final EventListItem item;

  /// Moderators see which events are seeded samples.
  final bool showSample;
  final void Function(int id) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (item) {
      CommunityEventItem(:final event) => Card(
        child: ListTile(
          key: Key('event-${event.id}'),
          leading: _DateBlock(event.startsAt, muted: event.isCancelled),
          title: Text(
            event.title,
            style: event.isCancelled
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  formatWhen(event.startsAt, event.endsAt),
                  if (event.isVirtual)
                    'Virtual'
                  else if (event.locationName.isNotEmpty)
                    event.locationName,
                ].join(' · '),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(context, event.scopeLabel),
                  if (event.isCancelled)
                    _chip(context, 'Cancelled', color: scheme.errorContainer),
                  if (showSample && event.isDemo) _chip(context, 'Sample'),
                  if (event.fundraiser != null)
                    _chip(
                      context,
                      'Fundraiser',
                      color: scheme.secondaryContainer,
                      icon: Icons.favorite_outline,
                    ),
                  if (event.myRsvp == 'going')
                    _chip(
                      context,
                      'Going',
                      color: scheme.primaryContainer,
                      icon: Icons.check,
                    ),
                  if (event.myRsvp == 'maybe') _chip(context, 'Maybe'),
                  if (event.myShiftCount > 0)
                    _chip(
                      context,
                      event.myShiftCount == 1
                          ? 'Volunteering'
                          : '${event.myShiftCount} shifts',
                      color: scheme.tertiaryContainer,
                      icon: Icons.volunteer_activism_outlined,
                    )
                  else if (event.openVolunteerSlots > 0 && !event.isCancelled)
                    _chip(
                      context,
                      '${event.openVolunteerSlots} volunteer '
                      '${event.openVolunteerSlots == 1 ? 'slot' : 'slots'}',
                      color: scheme.tertiaryContainer,
                    ),
                  if (event.isFull && event.myRsvp != 'going')
                    _chip(context, 'Full'),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () => onOpen(event.id),
        ),
      ),
      CampaignItem(:final candidate, :final opportunity) => Card(
        child: ListTile(
          leading: _DateBlock(opportunity.startsAt),
          title: Text(opportunity.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  formatWhen(opportunity.startsAt, opportunity.endsAt),
                  if (opportunity.location != null) opportunity.location!,
                ].join(' · '),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  _chip(
                    context,
                    'Campaign · ${candidate.name}',
                    color: scheme.secondaryContainer,
                    icon: Icons.how_to_vote_outlined,
                  ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(
            opportunity.signupUrl,
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    };
  }

  Widget _chip(
    BuildContext context,
    String label, {
    Color? color,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock(this.when, {this.muted = false});

  final DateTime when;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MMM').format(when).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted
                  ? scheme.onSurfaceVariant
                  : scheme.onPrimaryContainer,
            ),
          ),
          Text(
            '${when.day}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: muted
                  ? scheme.onSurfaceVariant
                  : scheme.onPrimaryContainer,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
