import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';

const _highlightLimit = 3;

/// What a group wants members to see before the posts: pinned and recent
/// announcements, upcoming events, and open polls (votable in place). The
/// console keeps the full lists and the management actions.
class GroupHighlights extends StatelessWidget {
  const GroupHighlights({
    super.key,
    required this.announcements,
    required this.events,
    required this.polls,
    required this.api,
    required this.onChanged,
    required this.onOpenConsole,
    this.canManage = false,
  });

  final List<GroupAnnouncement> announcements;
  final List<CommunityEvent> events;
  final List<GroupPoll> polls;
  final GroupConsoleService api;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenConsole;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final pinnedFirst = [...announcements]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return (b.createdAt ?? DateTime(0)).compareTo(
          a.createdAt ?? DateTime(0),
        );
      });
    final upcoming = [
      for (final e in events)
        if (!e.isCancelled && isUpcoming(e, now)) e,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final open = polls.where((p) => p.isOpen).toList();
    if (pinnedFirst.isEmpty && upcoming.isEmpty && open.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget heading(String title, int total) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (total > _highlightLimit)
            TextButton(onPressed: onOpenConsole, child: Text('See all $total')),
        ],
      ),
    );

    return Column(
      key: const Key('group-highlights'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinnedFirst.isNotEmpty) ...[
          heading('Announcements', pinnedFirst.length),
          for (final item in pinnedFirst.take(_highlightLimit))
            AnnouncementCard(announcement: item),
        ],
        if (upcoming.isNotEmpty) ...[
          heading('Upcoming events', upcoming.length),
          for (final event in upcoming.take(_highlightLimit))
            EventListCard(
              item: CommunityEventItem(event),
              showSample: canManage,
              onOpen: (id) => openEvent(context, id),
            ),
        ],
        if (open.isNotEmpty) ...[
          heading('Polls', open.length),
          for (final poll in open.take(_highlightLimit))
            PollCard(
              poll: poll,
              api: api,
              canManage: canManage,
              reload: onChanged,
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text('Posts', style: theme.textTheme.titleMedium),
        ),
      ],
    );
  }
}

/// One announcement, pinned ones marked.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement});

  final GroupAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = announcement;
    final meta = [
      if (a.author.isNotEmpty) a.author,
      if (a.createdAt != null) DateFormat('MMM d').format(a.createdAt!),
    ].join(' · ');
    return Card(
      key: Key('announcement-${a.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: a.isPinned ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a.isPinned) ...[
                  Icon(
                    Icons.push_pin_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(a.title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            if (a.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(a.body, maxLines: 6, overflow: TextOverflow.ellipsis),
            ],
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(meta, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _attempt(
  BuildContext context,
  Future<void> Function() call,
) async {
  try {
    await call();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('$e')));
    }
    return false;
  }
}

/// A poll with its results and, while open, a vote (or change of vote);
/// managers can close it. Shared by the feed and the console.
class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
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
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  late Set<int> _selected = widget.poll.myVotes.toSet();

  @override
  void didUpdateWidget(PollCard old) {
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
      key: Key('poll-${poll.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    key: Key('vote-${poll.id}'),
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
