import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/admin_console/admin_console_service.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/events/volunteer_roles.dart';
import 'package:npo_community/features/fundraisers/fundraiser_widgets.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/features/moderation/moderation_screen.dart';

/// The administrators' control console: the state of the platform at a
/// glance, every fundraiser, upcoming events, volunteers, and the status
/// of the VAN, Givebutter, email and image-screening integrations.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({
    super.key,
    this.service,
    this.fundraisers,
    this.events,
  });

  /// Injected in tests.
  final AdminConsoleService? service;
  final FundraisersService? fundraisers;
  final EventsService? events;

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  late final AdminConsoleService _service =
      widget.service ?? AdminConsoleService();
  late final FundraisersService _fundraisers =
      widget.fundraisers ?? FundraisersService();
  late final EventsService _events = widget.events ?? EventsService();
  late Future<AdminOverview> _overview = _service.fetchOverview();

  Future<void> _refresh() async {
    final overview = _service.fetchOverview();
    setState(() {
      _overview = overview;
    });
    try {
      await overview;
    } catch (_) {
      // The tab shows the error.
    }
  }

  void _openModeration() {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/admin/moderation');
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ModerationScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Control console'),
          actions: [
            IconButton(
              tooltip: 'Moderation panel',
              icon: const Icon(Icons.shield_outlined),
              onPressed: _openModeration,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Fundraising'),
              Tab(text: 'Events'),
              Tab(text: 'Volunteers'),
              Tab(text: 'Integrations'),
            ],
          ),
        ),
        body: FutureBuilder<AdminOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? _Message('${snapshot.error}', onRetry: _refresh)
                  : const Center(child: CircularProgressIndicator());
            }
            final overview = snapshot.data!;
            return TabBarView(
              children: [
                _OverviewTab(
                  overview: overview,
                  onRefresh: _refresh,
                  onModeration: _openModeration,
                ),
                _FundraisingTab(
                  overview: overview,
                  service: _fundraisers,
                  onChanged: _refresh,
                ),
                _EventsTab(overview: overview, service: _events),
                _VolunteersTab(overview: overview),
                _IntegrationsTab(overview: overview),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -- overview ------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.overview,
    required this.onRefresh,
    required this.onModeration,
  });

  final AdminOverview overview;
  final Future<void> Function() onRefresh;
  final VoidCallback onModeration;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final generated = o.generatedAt;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _Section(
            title: 'Members',
            children: [
              _Stat(
                keyName: 'members-total',
                value: '${o.count('members', 'total')}',
                label: 'members',
              ),
              _Stat(
                value: '${o.count('members', 'claimed')}',
                label: 'claimed profiles',
              ),
              _Stat(
                value: '${o.count('members', 'unclaimed')}',
                label: 'still unclaimed',
              ),
              _Stat(
                value: '${o.count('members', 'pending_signups')}',
                label: 'signups to review',
                attention: o.count('members', 'pending_signups') > 0,
              ),
              _Stat(
                value: '${o.count('members', 'under_moderation')}',
                label: 'under moderation',
                attention: o.count('members', 'under_moderation') > 0,
              ),
              _Stat(
                value: '${o.count('members', 'memorial')}',
                label: 'in memoriam',
              ),
            ],
          ),
          _Section(
            title: 'Moderation',
            trailing: TextButton(
              onPressed: onModeration,
              child: const Text('Open panel'),
            ),
            children: [
              _Stat(
                keyName: 'moderation-open',
                value: '${o.count('moderation', 'open')}',
                label: 'open reports',
                attention: o.count('moderation', 'open') > 0,
              ),
              _Stat(
                value: '${o.count('moderation', 'escalated')}',
                label: 'escalated',
              ),
              _Stat(
                value: '${o.count('moderation', 'total')}',
                label: 'reports ever',
              ),
            ],
          ),
          _Section(
            title: 'Fundraising',
            subtitle: o.text('fundraising', 'mode') == 'live'
                ? null
                : 'Preview until Givebutter is connected',
            children: [
              _Stat(
                keyName: 'fundraising-raised',
                value: formatDollars(o.count('fundraising', 'raised_cents')),
                label: 'raised',
              ),
              _Stat(
                value: formatDollars(o.count('fundraising', 'goal_cents')),
                label: 'in live goals',
              ),
              _Stat(
                value: '${o.count('fundraising', 'live')}',
                label: 'live fundraisers',
              ),
              _Stat(
                value: '${o.count('fundraising', 'pending_review')}',
                label: 'awaiting review',
                attention: o.count('fundraising', 'pending_review') > 0,
              ),
              _Stat(
                value: '${o.count('fundraising', 'donors')}',
                label: 'donors',
              ),
            ],
          ),
          _Section(
            title: 'Events & volunteers',
            children: [
              _Stat(
                keyName: 'events-upcoming',
                value: '${o.count('events', 'upcoming')}',
                label: 'upcoming events',
              ),
              _Stat(
                value: '${o.count('events', 'rsvps_going')}',
                label: 'RSVPs going',
              ),
              _Stat(
                value: '${o.count('events', 'open_slots')}',
                label: 'open volunteer slots',
                attention: o.count('events', 'open_slots') > 0,
              ),
              _Stat(
                value: _hours(o.number('events', 'hours_logged')),
                label: 'volunteer hours logged',
              ),
            ],
          ),
          _Section(
            title: 'Candidates & groups',
            children: [
              _Stat(
                keyName: 'candidates-on-ballot',
                value: '${o.count('candidates', 'on_ballot')}',
                label: 'alumnae on the ballot',
              ),
              _Stat(
                value: '${o.count('groups', 'candidates_members')}',
                label: 'in Candidates Running',
              ),
              _Stat(
                value: '${o.count('groups', 'statewide_members')}',
                label: 'in the statewide group',
              ),
              _Stat(
                value:
                    '${o.count('groups', 'regional')} / ${o.count('groups', 'cohort')}',
                label: 'regional / class groups',
              ),
            ],
          ),
          if (generated != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'As of ${DateFormat('MMM d, h:mm a').format(generated)}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

String _hours(double hours) => hours == hours.roundToDouble()
    ? hours.toStringAsFixed(0)
    : hours.toStringAsFixed(1);

// -- fundraising ---------------------------------------------------------------

class _FundraisingTab extends StatefulWidget {
  const _FundraisingTab({
    required this.overview,
    required this.service,
    required this.onChanged,
  });

  final AdminOverview overview;
  final FundraisersService service;
  final Future<void> Function() onChanged;

  @override
  State<_FundraisingTab> createState() => _FundraisingTabState();
}

class _FundraisingTabState extends State<_FundraisingTab>
    with AutomaticKeepAliveClientMixin {
  String _status = '';
  late Future<List<Fundraiser>> _future = widget.service.fetchAll(
    status: _status,
  );

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final future = widget.service.fetchAll(status: _status);
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final entry in const {
                '': 'All',
                'live': 'Live',
                'pending_review': 'Awaiting review',
                'closed': 'Closed',
                'rejected': 'Not approved',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _status == entry.key,
                    onSelected: (_) {
                      _status = entry.key;
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<Fundraiser>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return snapshot.hasError
                      ? _Message('${snapshot.error}', onRetry: _reload)
                      : const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                  children: [
                    if (widget.overview.text('fundraising', 'mode') != 'live')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          previewNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No fundraisers match.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final fundraiser in rows)
                      FundraiserCard(
                        fundraiser: fundraiser,
                        showSample: true,
                        onTap: () => showFundraiserSheet(
                          context,
                          fundraiser: fundraiser,
                          service: widget.service,
                          onChanged: () async {
                            await _reload();
                            await widget.onChanged();
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// -- events --------------------------------------------------------------------

class _EventsTab extends StatefulWidget {
  const _EventsTab({required this.overview, required this.service});

  final AdminOverview overview;
  final EventsService service;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<CommunityEvent>> _future = widget.service.fetchEvents(
    when: 'upcoming',
  );

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final future = widget.service.fetchEvents(when: 'upcoming');
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final o = widget.overview;
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<CommunityEvent>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? _Message('${snapshot.error}', onRetry: _reload)
                : const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              _Section(
                title: 'Upcoming',
                children: [
                  _Stat(
                    value: '${o.count('events', 'upcoming')}',
                    label: 'events',
                  ),
                  _Stat(
                    value: '${o.count('events', 'rsvps_going')}',
                    label: 'RSVPs going',
                  ),
                  _Stat(
                    value: '${o.count('events', 'volunteer_shifts')}',
                    label: 'volunteer shifts',
                  ),
                ],
              ),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No upcoming events.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final event in events)
                EventListCard(
                  item: CommunityEventItem(event),
                  showSample: true,
                  onOpen: (id) =>
                      openEvent(context, id, service: widget.service),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -- volunteers ----------------------------------------------------------------

class _VolunteersTab extends StatelessWidget {
  const _VolunteersTab({required this.overview});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final theme = Theme.of(context);
    final top = o.list('events', 'top_volunteers');
    final roles = o.subsection('members', 'volunteer_roles');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        _Section(
          title: 'Hours',
          children: [
            _Stat(
              keyName: 'volunteers-hours',
              value: _hours(o.number('events', 'hours_logged')),
              label: 'hours logged',
            ),
            _Stat(
              value: '${o.count('events', 'volunteers_logged')}',
              label: 'volunteers checked in',
            ),
            _Stat(
              value: '${o.count('events', 'open_slots')}',
              label: 'open slots to fill',
              attention: o.count('events', 'open_slots') > 0,
            ),
          ],
        ),
        Text('Top volunteers', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nobody has been checked in to a shift yet.'),
          )
        else
          for (final (index, row) in top.indexed)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(row['display_name']?.toString() ?? ''),
                trailing: Text(
                  '${_hours((row['hours'] as num?)?.toDouble() ?? 0)} h',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
        const SizedBox(height: 16),
        Text('Who has offered to help', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'From the "How I can help" choices on member profiles. Filter the '
          'directory by role to reach them.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in roles.entries)
              Chip(
                label: Text(
                  '${volunteerRoleLabel(entry.key)} · ${entry.value}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            if (GoRouter.maybeOf(context) != null) context.go('/directory');
          },
          icon: const Icon(Icons.people_outline),
          label: const Text('Open the directory'),
        ),
      ],
    );
  }
}

// -- integrations --------------------------------------------------------------

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab({required this.overview});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final van = o.subsection('integrations', 'van');
    final gb = o.subsection('integrations', 'givebutter');
    final email = o.subsection('integrations', 'email');
    final screening = o.subsection('integrations', 'image_screening');
    final gbLive = gb['mode'] == 'live';
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        _IntegrationCard(
          keyName: 'integration-van',
          title: 'NGP VAN / EveryAction',
          connected: van['configured'] == true,
          status: van['configured'] == true ? 'Connected' : 'Not connected',
          lines: [
            '${van['linked_accounts'] ?? 0} members linked to a VAN record',
            if (van['configured'] != true)
              'Needs the committee API key: set NGPVAN_APP_NAME and '
                  'NGPVAN_API_KEY on the server, then run sync_van_alumni.',
          ],
        ),
        _IntegrationCard(
          keyName: 'integration-givebutter',
          title: 'Givebutter',
          connected: gbLive,
          status: gbLive ? 'Live' : 'Preview',
          lines: [
            '${gb['live_campaigns'] ?? 0} live campaigns',
            gb['review_required'] == true
                ? 'Member fundraisers wait for a moderator before going live.'
                : 'Member fundraisers go live without review.',
            if (!gbLive)
              'Set GIVEBUTTER_API_KEY from Dashboard > Settings > '
                  'Integrations > API Keys to create real campaigns.',
          ],
        ),
        _IntegrationCard(
          keyName: 'integration-email',
          title: 'Email',
          connected: email['enabled'] == true,
          status: email['enabled'] == true ? 'Sending' : 'Off',
          lines: [
            email['enabled'] == true
                ? 'From ${email['from'] ?? ''}'
                : 'Claim invites and reset codes are shown to staff to relay '
                      'until EMAIL_HOST and credentials are set.',
          ],
        ),
        _IntegrationCard(
          keyName: 'integration-screening',
          title: 'Image screening',
          connected: screening['enabled'] == true,
          status: screening['enabled'] == true ? 'On' : 'Off',
          lines: const [
            'Uploaded photos are checked before they are saved; blocked '
                'uploads are written to the audit log.',
          ],
        ),
      ],
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.keyName,
    required this.title,
    required this.connected,
    required this.status,
    required this.lines,
  });

  final String keyName;
  final String title;
  final bool connected;
  final String status;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: Key(keyName),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: connected
                        ? scheme.primaryContainer
                        : scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: connected
                          ? scheme.onPrimaryContainer
                          : scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

// -- shared --------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ?trailing,
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.keyName,
    this.attention = false,
  });

  final String value;
  final String label;
  final String? keyName;

  /// Tinted when the number asks for action (open reports, empty slots).
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: keyName == null ? null : Key('stat-$keyName'),
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: attention ? scheme.tertiaryContainer : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: attention ? scheme.onTertiaryContainer : scheme.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: attention ? scheme.onTertiaryContainer : null,
            ),
          ),
        ],
      ),
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
