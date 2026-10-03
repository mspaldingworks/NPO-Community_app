import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/moderation/moderation_service.dart';

/// Moderation control panel: reports queue, member actions, audit log.
///
/// Staff, superusers and moderators reach it from Settings. The server
/// enforces every rule; this screen only hides buttons a viewer can't use
/// (lifting restrictions and role changes are superuser-only, protected
/// accounts are superuser-only).
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({
    super.key,
    this.service,
    this.isSuperuser = false,
    this.viewerId,
  });

  /// Optional injected service (used in tests).
  final ModerationService? service;
  final bool isSuperuser;
  final int? viewerId;

  @override
  Widget build(BuildContext context) {
    final api = service ?? ModerationService();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderation'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Reports'),
              Tab(text: 'Signups'),
              Tab(text: 'Claims'),
              Tab(text: 'Members'),
              Tab(text: 'Audit log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReportsTab(service: api),
            _SignupsTab(service: api, isSuperuser: isSuperuser),
            _ClaimsTab(service: api),
            _MembersTab(
              service: api,
              isSuperuser: isSuperuser,
              viewerId: viewerId,
            ),
            _AuditTab(service: api),
          ],
        ),
      ),
    );
  }
}

const _statusLabels = {
  'active': 'Active',
  'warned': 'Warned',
  'restricted': 'Restricted',
  'suspended': 'Suspended',
  'banned': 'Banned',
};

const _actionLabels = {
  'warn': 'Warn',
  'restrict': 'Restrict (read-only)',
  'suspend': 'Suspend',
  'ban': 'Ban',
};

const _targetLabels = {
  'post': 'Post',
  'comment': 'Comment',
  'message': 'Direct message',
  'chatMessage': 'Chat message',
  'photo': 'Photo',
  'status': 'Status',
  'statusComment': 'Status comment',
  'user': 'Member',
  'other': 'Other',
};

String _when(DateTime? when) =>
    when == null ? '' : DateFormat('MMM d, h:mm a').format(when);

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final serious = status == 'suspended' || status == 'banned';
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusLabels[status] ?? status),
      backgroundColor: serious
          ? colors.errorContainer
          : status == 'active'
          ? null
          : colors.tertiaryContainer,
    );
  }
}

// -- dialogs -----------------------------------------------------------------

class _ActionInput {
  const _ActionInput(this.reason, this.until);

  final String reason;
  final DateTime? until;
}

/// Asks for a required reason (and, for suspensions, an optional end date).
Future<_ActionInput?> _askReason(
  BuildContext context, {
  required String title,
  bool askUntil = false,
  String confirmLabel = 'Confirm',
  bool reasonRequired = true,
}) {
  final controller = TextEditingController();
  DateTime? until;
  return showDialog<_ActionInput>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('moderation-reason'),
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                labelText: reasonRequired ? 'Reason (required)' : 'Notes',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (askUntil) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      until == null
                          ? 'Until lifted'
                          : 'Until ${DateFormat.yMMMd().format(until!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: now.add(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 365)),
                        initialDate: now.add(const Duration(days: 7)),
                      );
                      if (picked != null) setState(() => until = picked);
                    },
                    child: const Text('Set end date'),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: reasonRequired && controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    dialogContext,
                    _ActionInput(controller.text.trim(), until),
                  ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _pickAction(BuildContext context) => showDialog<String>(
  context: context,
  builder: (dialogContext) => SimpleDialog(
    title: const Text('Act on the reported member'),
    children: [
      for (final entry in _actionLabels.entries)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, entry.key),
          child: Text(entry.value),
        ),
    ],
  ),
);

// -- reports -----------------------------------------------------------------

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.service});

  final ModerationService service;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'active';
  late Future<ModerationPage<ModerationReport>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<ModerationPage<ModerationReport>> _load() =>
      widget.service.fetchReports(status: _filter);

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _run(Future<void> Function() call, String done) async {
    try {
      await call();
      if (mounted) _snack(context, done);
      await _refresh();
    } catch (e) {
      if (mounted) _snack(context, '$e');
    }
  }

  Future<void> _close(ModerationReport report, String status) async {
    final input = await _askReason(
      context,
      title: status == 'dismissed' ? 'Dismiss report' : 'Resolve report',
      reasonRequired: false,
    );
    if (input == null) return;
    await _run(
      () => widget.service.resolveReport(
        report.id,
        status: status,
        notes: input.reason,
      ),
      status == 'dismissed' ? 'Report dismissed.' : 'Report resolved.',
    );
  }

  Future<void> _escalate(ModerationReport report) async {
    final action = await _pickAction(context);
    if (action == null || !mounted) return;
    final input = await _askReason(
      context,
      title: '${_actionLabels[action]} ${report.targetUser?.displayName ?? ''}',
      askUntil: action == 'suspend',
    );
    if (input == null) return;
    await _run(
      () => widget.service.escalateReport(
        report.id,
        action: action,
        reason: input.reason,
        suspensionUntil: input.until,
      ),
      'Action taken.',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'active', label: Text('Open')),
              ButtonSegment(value: 'all', label: Text('All')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) {
              _filter = value.first;
              _refresh();
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<ModerationPage<ModerationReport>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message('Reports are unavailable: ${snapshot.error}');
                }
                final reports = snapshot.data!.results;
                if (reports.isEmpty) {
                  return const _Message('No reports to review.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: reports.length,
                  itemBuilder: (context, index) => _ReportCard(
                    report: reports[index],
                    onReview: () => _run(
                      () => widget.service.resolveReport(
                        reports[index].id,
                        status: 'reviewing',
                      ),
                      'Marked as reviewing.',
                    ),
                    onResolve: () => _close(reports[index], 'resolved'),
                    onDismiss: () => _close(reports[index], 'dismissed'),
                    onEscalate: () => _escalate(reports[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onReview,
    required this.onResolve,
    required this.onDismiss,
    required this.onEscalate,
  });

  final ModerationReport report;
  final VoidCallback onReview;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = report.targetUser;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_targetLabels[report.targetType] ?? report.targetType}'
                    ' · ${report.reason}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(_when(report.createdAt), style: theme.textTheme.bodySmall),
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reported member: ${target.displayName} (@${target.username})'
                '${target.moderationStatus != null && target.moderationStatus != 'active' ? ' · ${_statusLabels[target.moderationStatus] ?? target.moderationStatus}' : ''}',
              ),
            ],
            if (report.evidenceText != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Text(report.evidenceText!),
              ),
            ],
            if (report.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reporter notes: ${report.details}'),
            ],
            const SizedBox(height: 4),
            Text(
              'Reported by ${report.reporter?.displayName ?? 'a deleted account'}'
              ' · ${report.status}'
              '${report.memberAction.isNotEmpty ? ' (${report.memberAction})' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (report.resolutionNotes.isNotEmpty)
              Text(
                'Notes: ${report.resolutionNotes}',
                style: theme.textTheme.bodySmall,
              ),
            if (report.isActive)
              Wrap(
                spacing: 8,
                children: [
                  if (report.status == 'open')
                    TextButton(
                      onPressed: onReview,
                      child: const Text('Review'),
                    ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: onResolve,
                    child: const Text('Resolve'),
                  ),
                  if (target != null)
                    FilledButton.tonal(
                      onPressed: onEscalate,
                      child: const Text('Act on member'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// -- signups -----------------------------------------------------------------

class _SignupsTab extends StatefulWidget {
  const _SignupsTab({required this.service, required this.isSuperuser});

  final ModerationService service;
  final bool isSuperuser;

  @override
  State<_SignupsTab> createState() => _SignupsTabState();
}

class _SignupsTabState extends State<_SignupsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<ModerationPage<PendingSignup>> _future = widget.service
      .fetchSignups();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final future = widget.service.fetchSignups();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _decide(
    PendingSignup signup,
    String decision, {
    ClaimRecord? record,
    ClaimSuggestion? suggestion,
  }) async {
    final target = record?.displayName ?? suggestion?.ref.displayName;
    final title = switch (decision) {
      'link' => 'Link ${signup.username} to $target',
      'verify' => 'Verify ${signup.username} (not on the roster)',
      _ => 'Reject ${signup.username}',
    };
    final input = await _askReason(context, title: title);
    if (input == null) return;
    try {
      await widget.service.decideSignup(
        signup.id,
        decision,
        reason: input.reason,
        seedAccountId: record?.id ?? suggestion?.ref.id,
      );
      if (mounted) _snack(context, 'Done.');
      await _refresh();
    } catch (e) {
      if (mounted) _snack(context, '$e');
    }
  }

  Future<void> _pickRecord(PendingSignup signup) async {
    final record = await showModalBottomSheet<ClaimRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: _RosterPicker(service: widget.service),
      ),
    );
    if (record != null && mounted) {
      await _decide(signup, 'link', record: record);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ModerationPage<PendingSignup>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message('Signups are unavailable: ${snapshot.error}');
          }
          final signups = snapshot.data!.results;
          if (signups.isEmpty) {
            return const _Message('No signups are waiting for verification.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: signups.length,
            itemBuilder: (context, index) {
              final signup = signups[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${signup.username}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        [
                          if (signup.email != null) signup.email!,
                          if (signup.programYear != null)
                            'says Class of ${signup.programYear}',
                          if (signup.dateJoined != null)
                            'joined ${_when(signup.dateJoined)}',
                        ].join(' · '),
                      ),
                      if (signup.suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Possible roster matches:'),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final match in signup.suggestions)
                              ActionChip(
                                label: Text(
                                  '${match.ref.displayName}'
                                  '${match.programYear != null ? ' (${match.programYear})' : ''}',
                                ),
                                onPressed: () =>
                                    _decide(signup, 'link', suggestion: match),
                              ),
                          ],
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _pickRecord(signup),
                            child: const Text('Link to…'),
                          ),
                          TextButton(
                            onPressed: () => _decide(signup, 'verify'),
                            child: const Text('Verify (not on roster)'),
                          ),
                          TextButton(
                            onPressed: () => _decide(signup, 'reject'),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Search unclaimed roster records to link a signup to.
class _RosterPicker extends StatefulWidget {
  const _RosterPicker({required this.service});

  final ModerationService service;

  @override
  State<_RosterPicker> createState() => _RosterPickerState();
}

class _RosterPickerState extends State<_RosterPicker> {
  final _search = TextEditingController();
  late Future<ModerationPage<ClaimRecord>> _future = _load();

  Future<ModerationPage<ClaimRecord>> _load() =>
      widget.service.fetchClaims(search: _search.text.trim());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search the alumnae roster',
            ),
            onSubmitted: (_) => setState(() {
              _future = _load();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<ModerationPage<ClaimRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? _Message('${snapshot.error}')
                    : const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data!.results
                  .where((r) => r.canInvite)
                  .toList();
              if (records.isEmpty) return const _Message('No unclaimed match.');
              return ListView(
                children: [
                  for (final record in records)
                    ListTile(
                      title: Text(record.displayName),
                      subtitle: Text(
                        '@${record.username}'
                        '${record.programYear != null ? ' · Class of ${record.programYear}' : ''}',
                      ),
                      onTap: () => Navigator.pop(context, record),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// -- claims ------------------------------------------------------------------

const _claimLabels = {
  'unclaimed': 'Unclaimed',
  'invited': 'Invited',
  'claimed': 'Claimed',
  'memorial': 'Memorial',
};

class _ClaimsTab extends StatefulWidget {
  const _ClaimsTab({required this.service});

  final ModerationService service;

  @override
  State<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<_ClaimsTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String _status = 'unclaimed';
  late Future<ModerationPage<ClaimRecord>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<ModerationPage<ClaimRecord>> _load() =>
      widget.service.fetchClaims(status: _status, search: _search.text.trim());

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _invite(ClaimRecord record) async {
    final controller = TextEditingController(text: record.email ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Invite ${record.displayName}'),
        content: TextField(
          key: const Key('claim-invite-email'),
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email from Emerge records',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(
              record.status == 'invited' ? 'New code' : 'Create code',
            ),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      final invite = await widget.service.inviteClaim(record.id, email: email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Claim code: ${invite.code}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send this to her now; the code is not shown again. Any '
                'earlier code for this profile no longer works.',
              ),
              const SizedBox(height: 12),
              SelectableText(invite.message),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.message));
                if (dialogContext.mounted) {
                  _snack(dialogContext, 'Copied.');
                }
              },
              child: const Text('Copy message'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await _refresh();
    } catch (e) {
      if (mounted) _snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search the roster',
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _status,
                items: [
                  for (final entry in _claimLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  _status = value ?? 'unclaimed';
                  _refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<ModerationPage<ClaimRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message('Claims are unavailable: ${snapshot.error}');
                }
                final page = snapshot.data!;
                if (page.results.isEmpty) {
                  return const _Message('Nobody here.');
                }
                return ListView.separated(
                  itemCount: page.results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = page.results[index];
                    return ListTile(
                      title: Text(record.displayName),
                      subtitle: Text(
                        [
                          if (record.programYear != null)
                            'Class of ${record.programYear}',
                          _claimLabels[record.status] ?? record.status,
                          if (record.email != null) record.email!,
                          if (record.invitedAt != null)
                            'invited ${_when(record.invitedAt)}',
                          if (record.openedAt != null)
                            'opened ${_when(record.openedAt)}',
                          if (record.claimedAt != null)
                            'claimed ${_when(record.claimedAt)}',
                        ].join(' · '),
                      ),
                      trailing: record.canInvite
                          ? TextButton(
                              onPressed: () => _invite(record),
                              child: Text(
                                record.status == 'invited'
                                    ? 'Resend'
                                    : 'Invite',
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// -- members -----------------------------------------------------------------

class _MembersTab extends StatefulWidget {
  const _MembersTab({
    required this.service,
    required this.isSuperuser,
    required this.viewerId,
  });

  final ModerationService service;
  final bool isSuperuser;
  final int? viewerId;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String _status = '';
  late Future<ModerationPage<ModerationMember>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<ModerationPage<ModerationMember>> _load() =>
      widget.service.fetchMembers(search: _search.text.trim(), status: _status);

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _open(ModerationMember member) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberSheet(
        member: member,
        service: widget.service,
        isSuperuser: widget.isSuperuser,
        isSelf: member.id == widget.viewerId,
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search members',
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _status,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Everyone')),
                  for (final entry in _statusLabels.entries)
                    if (entry.key != 'active')
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                ],
                onChanged: (value) {
                  _status = value ?? '';
                  _refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<ModerationPage<ModerationMember>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message('Members are unavailable: ${snapshot.error}');
                }
                final page = snapshot.data!;
                if (page.results.isEmpty) {
                  return const _Message('No members match.');
                }
                return ListView.separated(
                  itemCount: page.results.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == page.results.length) {
                      return page.count > page.results.length
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Showing ${page.results.length} of '
                                '${page.count}. Search to narrow the list.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : const SizedBox.shrink();
                    }
                    final member = page.results[index];
                    return ListTile(
                      title: Text(member.displayName),
                      subtitle: Text(
                        [
                          '@${member.username}',
                          if (member.programYear != null)
                            'Class of ${member.programYear}',
                          if (member.isMemorial) 'In memoriam',
                          if (member.claimStatus == 'unclaimed') 'Unclaimed',
                          ...member.roles.where((r) => r != 'alumni'),
                        ].join(' · '),
                      ),
                      leading: member.isProtected
                          ? const Icon(Icons.shield_outlined)
                          : const Icon(Icons.person_outline),
                      trailing: member.moderationStatus == 'active'
                          ? null
                          : _StatusChip(member.moderationStatus),
                      onTap: () => _open(member),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({
    required this.member,
    required this.service,
    required this.isSuperuser,
    required this.isSelf,
  });

  final ModerationMember member;
  final ModerationService service;
  final bool isSuperuser;
  final bool isSelf;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  bool _busy = false;

  ModerationMember get member => widget.member;

  bool get _canAct =>
      !widget.isSelf && (!member.isProtected || widget.isSuperuser);

  Future<void> _do(Future<void> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      _snack(context, done);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action) async {
    final input = await _askReason(
      context,
      title: '${_actionLabels[action]} ${member.displayName}',
      askUntil: action == 'suspend',
    );
    if (input == null) return;
    await _do(
      () => widget.service.memberAction(
        member.id,
        action,
        reason: input.reason,
        suspensionUntil: input.until,
      ),
      'Done: ${_actionLabels[action]}.',
    );
  }

  Future<void> _lift() async {
    final input = await _askReason(
      context,
      title: 'Lift restriction on ${member.displayName}',
    );
    if (input == null) return;
    await _do(
      () =>
          widget.service.memberAction(member.id, 'lift', reason: input.reason),
      'Restriction lifted.',
    );
  }

  Future<void> _role(String role, bool grant) async {
    final label = role == 'admin' ? 'admin' : 'moderator';
    final input = await _askReason(
      context,
      title: grant
          ? 'Make ${member.displayName} a $label'
          : 'Remove $label from ${member.displayName}',
    );
    if (input == null) return;
    await _do(
      () => widget.service.setRole(
        member.id,
        role: role,
        grant: grant,
        reason: input.reason,
      ),
      grant ? 'Now a $label.' : 'No longer a $label.',
    );
  }

  Future<void> _history() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _AuditList(service: widget.service, targetId: member.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                _StatusChip(member.moderationStatus),
              ],
            ),
            Text(
              [
                '@${member.username}',
                if (member.email != null) member.email!,
                if (member.roles.isNotEmpty) member.roles.join(', '),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (member.moderationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reason: ${member.moderationReason}'),
            ],
            if (member.suspensionUntil != null)
              Text('Suspended until ${_when(member.suspensionUntil)}'),
            const SizedBox(height: 12),
            if (!_canAct)
              Text(
                widget.isSelf
                    ? 'You cannot moderate your own account.'
                    : 'Staff, moderators and admins can only be actioned by a superuser.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in _actionLabels.keys)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _action(action),
                      child: Text(_actionLabels[action]!),
                    ),
                  if (widget.isSuperuser && member.moderationStatus != 'active')
                    FilledButton(
                      onPressed: _busy ? null : _lift,
                      child: const Text('Lift restriction'),
                    ),
                ],
              ),
            if (widget.isSuperuser && !widget.isSelf) ...[
              const Divider(height: 28),
              Text('Roles', style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final role in const ['moderator', 'admin'])
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _role(role, !member.hasRole(role)),
                      child: Text(
                        member.hasRole(role)
                            ? 'Remove ${role == 'admin' ? 'admin' : 'moderator'}'
                            : 'Make ${role == 'admin' ? 'admin' : 'moderator'}',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _history,
              icon: const Icon(Icons.history),
              label: const Text('History'),
            ),
          ],
        ),
      ),
    );
  }
}

// -- audit log ---------------------------------------------------------------

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.service});

  final ModerationService service;

  @override
  Widget build(BuildContext context) => _AuditList(service: service);
}

class _AuditList extends StatefulWidget {
  const _AuditList({required this.service, this.targetId});

  final ModerationService service;
  final int? targetId;

  @override
  State<_AuditList> createState() => _AuditListState();
}

class _AuditListState extends State<_AuditList> {
  late Future<ModerationPage<AuditEntry>> _future = _load();

  Future<ModerationPage<AuditEntry>> _load() =>
      widget.service.fetchAudit(targetId: widget.targetId);

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ModerationPage<AuditEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message('The audit log is unavailable: ${snapshot.error}');
          }
          final entries = snapshot.data!.results;
          if (entries.isEmpty) return const _Message('Nothing recorded yet.');
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final action = entry.action.replaceFirst('moderation:', '');
              final denied = entry.outcome == 'denied';
              return ListTile(
                dense: true,
                leading: Icon(
                  denied ? Icons.block : Icons.check_circle_outline,
                  color: denied ? Theme.of(context).colorScheme.error : null,
                ),
                title: Text(
                  '${entry.actor?.displayName ?? 'System'} · $action'
                  '${entry.target != null ? ' · ${entry.target!.displayName}' : ''}',
                ),
                subtitle: Text(
                  [
                    _when(entry.createdAt),
                    if (denied) 'denied (${entry.reason})',
                    if (entry.notes.isNotEmpty) entry.notes,
                  ].join(' · '),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
    children: [Text(text, textAlign: TextAlign.center)],
  );
}
