import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/events/event_form.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';
import 'package:npo_community/features/moderation/moderation_service.dart';

/// A group's console: welcome and rules, announcements, events and polls.
///
/// Every member can read and vote. Managers (moderators and the group's
/// appointed admins) edit settings and post; moderators also appoint admins.
/// The server enforces all of it; this screen only hides what a viewer can't
/// use.
class GroupConsoleScreen extends StatefulWidget {
  const GroupConsoleScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.service,
    this.memberSearch,
  });

  final int groupId;
  final String groupName;

  /// Optional injected services (used in tests).
  final GroupConsoleService? service;
  final ModerationService? memberSearch;

  @override
  State<GroupConsoleScreen> createState() => _GroupConsoleScreenState();
}

class _GroupConsoleScreenState extends State<GroupConsoleScreen> {
  late final GroupConsoleService _api =
      widget.service ?? GroupConsoleService(widget.groupId);
  late Future<GroupConsoleOverview> _overview = _api.fetchOverview();

  Future<void> _reload() async {
    final future = _api.fetchOverview();
    setState(() {
      _overview = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'About'),
              Tab(text: 'Announcements'),
              Tab(text: 'Events'),
              Tab(text: 'Polls'),
            ],
          ),
        ),
        body: FutureBuilder<GroupConsoleOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? _Message(
                      'This group\'s console is unavailable: ${snapshot.error}',
                    )
                  : const Center(child: CircularProgressIndicator());
            }
            final overview = snapshot.data!;
            return TabBarView(
              children: [
                _AboutTab(
                  api: _api,
                  overview: overview,
                  onChanged: _reload,
                  memberSearch: widget.memberSearch,
                ),
                _AnnouncementsTab(api: _api, canManage: overview.canManage),
                _EventsTab(api: _api, canManage: overview.canManage),
                _PollsTab(api: _api, canManage: overview.canManage),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String text) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(text)));

String _when(DateTime when) => DateFormat('EEE, MMM d · h:mm a').format(when);

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
    children: [Text(text, textAlign: TextAlign.center)],
  );
}

/// Loads a list, shows it, and offers a manager-only "add" button.
class _ListTab<T> extends StatefulWidget {
  const _ListTab({
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.onAdd,
    this.addLabel = 'Add',
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload)
  itemBuilder;
  final String empty;
  final Future<bool> Function(BuildContext)? onAdd;
  final String addLabel;

  @override
  State<_ListTab<T>> createState() => _ListTabState<T>();
}

class _ListTabState<T> extends State<_ListTab<T>>
    with AutomaticKeepAliveClientMixin {
  late Future<List<T>> _future = widget.load();

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    final future = widget.load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (await widget.onAdd!(context)) await _reload();
              },
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<T>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? _Message('${snapshot.error}')
                  : const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) return _Message(widget.empty);
            return ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              children: [
                for (final item in items)
                  widget.itemBuilder(context, item, _reload),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<Map<String, String>?> _form(
  BuildContext context, {
  required String title,
  required List<(String key, String label, int lines)> fields,
}) {
  final controllers = {for (final f in fields) f.$1: TextEditingController()};
  return showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, label, lines) in fields)
              TextField(
                key: Key('console-$key'),
                controller: controllers[key],
                maxLines: lines,
                minLines: 1,
                decoration: InputDecoration(labelText: label),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, {
            for (final entry in controllers.entries)
              entry.key: entry.value.text.trim(),
          }),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> _attempt(
  BuildContext context,
  Future<void> Function() call,
) async {
  try {
    await call();
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, '$e');
    return false;
  }
}

// -- about ---------------------------------------------------------------------

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.api,
    required this.overview,
    required this.onChanged,
    this.memberSearch,
  });

  final GroupConsoleService api;
  final GroupConsoleOverview overview;
  final Future<void> Function() onChanged;
  final ModerationService? memberSearch;

  Future<void> _editSettings(BuildContext context) async {
    final values = await _form(
      context,
      title: 'Welcome and rules',
      fields: const [('welcome', 'Welcome message', 4), ('rules', 'Rules', 6)],
    );
    if (values == null || !context.mounted) return;
    if (await _attempt(
      context,
      () => api.saveSettings(
        welcomeMessage: values['welcome'],
        rules: values['rules'],
      ),
    )) {
      await onChanged();
    }
  }

  Future<void> _addAdmin(BuildContext context) async {
    final search = memberSearch ?? ModerationService();
    final picked = await showDialog<ModerationMember>(
      context: context,
      builder: (_) => _MemberPicker(search: search),
    );
    if (picked == null || !context.mounted) return;
    if (await _attempt(context, () => api.setAdmin(picked.id, appoint: true))) {
      await onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (overview.isLocked)
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Only this group\'s admins can post right now.'),
            ),
          ),
        Text('Welcome', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          overview.welcomeMessage.isEmpty
              ? 'No welcome message yet.'
              : overview.welcomeMessage,
        ),
        const SizedBox(height: 16),
        Text('Rules', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(overview.rules.isEmpty ? 'No rules posted yet.' : overview.rules),
        const SizedBox(height: 16),
        Text('Group admins', style: theme.textTheme.titleMedium),
        Wrap(
          spacing: 6,
          children: [
            if (overview.admins.isEmpty)
              const Text('Moderators run this group.'),
            for (final admin in overview.admins)
              InputChip(
                label: Text(admin.name),
                onDeleted: overview.canAppoint
                    ? () async {
                        if (await _attempt(
                          context,
                          () => api.setAdmin(admin.id, appoint: false),
                        )) {
                          await onChanged();
                        }
                      }
                    : null,
              ),
          ],
        ),
        if (overview.canAppoint)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addAdmin(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add admin'),
            ),
          ),
        if (overview.canManage) ...[
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock posting'),
            subtitle: const Text('Only group admins and moderators can post.'),
            value: overview.isLocked,
            onChanged: (locked) async {
              if (await _attempt(
                context,
                () => api.saveSettings(isLocked: locked),
              )) {
                await onChanged();
              }
            },
          ),
          OutlinedButton.icon(
            onPressed: () => _editSettings(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit welcome and rules'),
          ),
        ],
      ],
    );
  }
}

class _MemberPicker extends StatefulWidget {
  const _MemberPicker({required this.search});

  final ModerationService search;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final _query = TextEditingController();
  Future<ModerationPage<ModerationMember>>? _results;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a group admin'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search members',
              ),
              onSubmitted: (value) => setState(() {
                _results = widget.search.fetchMembers(search: value.trim());
              }),
            ),
            Expanded(
              child: _results == null
                  ? const SizedBox.shrink()
                  : FutureBuilder<ModerationPage<ModerationMember>>(
                      future: _results,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return snapshot.hasError
                              ? Text('${snapshot.error}')
                              : const Center(
                                  child: CircularProgressIndicator(),
                                );
                        }
                        return ListView(
                          children: [
                            for (final member in snapshot.data!.results)
                              ListTile(
                                title: Text(member.displayName),
                                subtitle: Text('@${member.username}'),
                                onTap: () => Navigator.pop(context, member),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- announcements -------------------------------------------------------------

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({required this.api, required this.canManage});

  final GroupConsoleService api;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return _ListTab<GroupAnnouncement>(
      load: api.fetchAnnouncements,
      empty: 'No announcements yet.',
      addLabel: 'Announce',
      onAdd: !canManage
          ? null
          : (context) async {
              final values = await _form(
                context,
                title: 'New announcement',
                fields: const [('title', 'Title', 1), ('body', 'Message', 6)],
              );
              if (values == null ||
                  values['title']!.isEmpty ||
                  !context.mounted) {
                return false;
              }
              return _attempt(
                context,
                () => api.postAnnouncement(
                  title: values['title']!,
                  body: values['body']!,
                ),
              );
            },
      itemBuilder: (context, item, reload) => Card(
        child: ListTile(
          leading: item.isPinned ? const Icon(Icons.push_pin_outlined) : null,
          title: Text(item.title),
          subtitle: Text(
            [
              if (item.body.isNotEmpty) item.body,
              [
                item.author,
                if (item.createdAt != null) _when(item.createdAt!),
              ].where((s) => s.isNotEmpty).join(' · '),
            ].join('\n'),
          ),
          isThreeLine: item.body.isNotEmpty,
          trailing: canManage
              ? IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await _attempt(
                      context,
                      () => api.deleteAnnouncement(item.id),
                    )) {
                      await reload();
                    }
                  },
                )
              : null,
        ),
      ),
    );
  }
}

// -- events --------------------------------------------------------------------

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.api, required this.canManage});

  final GroupConsoleService api;
  final bool canManage;

  Future<bool> _add(BuildContext context) =>
      showEventForm(context, onSubmit: api.postEvent);

  @override
  Widget build(BuildContext context) {
    return _ListTab<CommunityEvent>(
      load: api.fetchEvents,
      empty: 'No upcoming events.',
      addLabel: 'Event',
      onAdd: canManage ? _add : null,
      itemBuilder: (context, event, reload) => Card(
        child: ListTile(
          key: Key('console-event-${event.id}'),
          leading: Icon(
            event.isCancelled
                ? Icons.event_busy_outlined
                : Icons.event_outlined,
          ),
          title: Text(
            event.isCancelled ? '${event.title} (cancelled)' : event.title,
          ),
          subtitle: Text(
            [
              _when(event.startsAt),
              if (event.locationName.isNotEmpty) event.locationName,
              if (event.isVirtual && event.virtualLink.isNotEmpty)
                event.virtualLink,
              '${event.goingCount} going'
                  '${event.openVolunteerSlots > 0 ? ' · ${event.openVolunteerSlots} volunteer slots open' : ''}',
            ].join('\n'),
          ),
          isThreeLine: true,
          onTap: () => openEvent(context, event.id),
          trailing: canManage && !event.isCancelled
              ? TextButton(
                  onPressed: () async {
                    if (await _attempt(
                      context,
                      () => api.cancelEvent(event.id),
                    )) {
                      await reload();
                    }
                  },
                  child: const Text('Cancel'),
                )
              : null,
        ),
      ),
    );
  }
}

// -- polls ---------------------------------------------------------------------

class _PollsTab extends StatelessWidget {
  const _PollsTab({required this.api, required this.canManage});

  final GroupConsoleService api;
  final bool canManage;

  Future<bool> _create(BuildContext context) async {
    final values = await _form(
      context,
      title: 'New poll',
      fields: const [
        ('question', 'Question', 2),
        ('options', 'Options, one per line', 5),
      ],
    );
    if (values == null || !context.mounted) return false;
    final options = values['options']!
        .split('\n')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    return _attempt(
      context,
      () => api.createPoll(question: values['question']!, options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ListTab<GroupPoll>(
      load: api.fetchPolls,
      empty: 'No polls yet.',
      addLabel: 'Poll',
      onAdd: canManage ? _create : null,
      itemBuilder: (context, poll, reload) =>
          _PollCard(poll: poll, api: api, canManage: canManage, reload: reload),
    );
  }
}

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.api,
    required this.canManage,
    required this.reload,
  });

  final GroupPoll poll;
  final GroupConsoleService api;
  final bool canManage;
  final Future<void> Function() reload;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late Set<int> _selected = widget.poll.myVotes.toSet();

  @override
  void didUpdateWidget(_PollCard old) {
    super.didUpdateWidget(old);
    _selected = widget.poll.myVotes.toSet();
  }

  void _toggle(int optionId) => setState(() {
    if (widget.poll.allowMultiple) {
      _selected.contains(optionId)
          ? _selected.remove(optionId)
          : _selected.add(optionId);
    } else {
      _selected = {optionId};
    }
  });

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final theme = Theme.of(context);
    final total = poll.options.fold<int>(0, (sum, o) => sum + o.votes);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.question, style: theme.textTheme.titleSmall),
            Text(
              [
                poll.isOpen ? 'Open' : 'Closed',
                poll.allowMultiple ? 'choose any' : 'choose one',
                poll.isAnonymous ? 'anonymous' : 'names shown',
                '${poll.totalVoters} voted',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            for (final option in poll.options)
              InkWell(
                onTap: poll.isOpen ? () => _toggle(option.id) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selected.contains(option.id)
                                ? (poll.allowMultiple
                                      ? Icons.check_box
                                      : Icons.radio_button_checked)
                                : (poll.allowMultiple
                                      ? Icons.check_box_outline_blank
                                      : Icons.radio_button_unchecked),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(option.text)),
                          Text('${option.votes}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : option.votes / total,
                      ),
                      if (option.voters != null && option.voters!.isNotEmpty)
                        Text(
                          option.voters!.join(', '),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (poll.isOpen)
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () async {
                            if (await _attempt(
                              context,
                              () =>
                                  widget.api.vote(poll.id, _selected.toList()),
                            )) {
                              await widget.reload();
                            }
                          },
                    child: Text(poll.myVotes.isEmpty ? 'Vote' : 'Change vote'),
                  ),
                if (poll.isOpen && widget.canManage)
                  TextButton(
                    onPressed: () async {
                      if (await _attempt(
                        context,
                        () => widget.api.closePoll(poll.id),
                      )) {
                        await widget.reload();
                      }
                    },
                    child: const Text('Close poll'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
