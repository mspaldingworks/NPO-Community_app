import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/program_service.dart';
import 'package:npo_community/features/people/people_service.dart';
import 'package:share_plus/share_plus.dart';

String _error(Object error) =>
    error is ApiClientException ? error.message : '$error';

void _say(BuildContext context, String message) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(message)));

/// The control console's People tab (staff and administrators): find a
/// member and give or remove roles, board included; invite new members by
/// link; see and revoke invitations.
class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key, required this.service});

  final PeopleService service;

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '';
  late Future<List<Person>> _people = widget.service.search('');
  late Future<List<Invite>> _invites = widget.service.fetchInvites();
  late final Future<List<RoleOption>> _roles = widget.service
      .fetchRoleOptions();

  @override
  bool get wantKeepAlive => true;

  void _reload() => setState(() {
    _people = widget.service.search(_query);
    _invites = widget.service.fetchInvites();
  });

  Future<void> _open(Person person, List<RoleOption> roles) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PersonSheet(person: person, roles: roles, service: widget.service),
    );
    if (changed == true) _reload();
  }

  Future<void> _invite(List<RoleOption> roles) async {
    final invite = await showModalBottomSheet<Invite>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(roles: roles, service: widget.service),
    );
    if (invite == null || !mounted) return;
    _reload();
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteCreatedDialog(invite: invite),
    );
  }

  Future<void> _revoke(Invite invite) async {
    try {
      await widget.service.revokeInvite(invite.id);
      if (mounted) _say(context, 'Invite ${invite.code} revoked.');
      _reload();
    } catch (e) {
      if (mounted) _say(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return FutureBuilder<List<RoleOption>>(
      future: _roles,
      builder: (context, roleSnapshot) {
        if (!roleSnapshot.hasData) {
          return Center(
            child: roleSnapshot.hasError
                ? Text(_error(roleSnapshot.error!))
                : const CircularProgressIndicator(),
          );
        }
        final roles = roleSnapshot.data!;
        final labels = {for (final r in roles) r.key: r.label};
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            key: const Key('people-tab'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Give members roles (board, committee, moderator and '
                      'more) and invite new members.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('invite-someone'),
                    onPressed: () => _invite(roles),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Invite someone'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('people-search'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Find a member',
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _query = value.trim();
                  _reload();
                },
              ),
              FutureBuilder<List<Person>>(
                future: _people,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: snapshot.hasError
                            ? Text(_error(snapshot.error!))
                            : const CircularProgressIndicator(),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final person in snapshot.data!)
                        ListTile(
                          key: Key('person-${person.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(person.displayName),
                          subtitle: Text(
                            [
                              if (person.programYear != null)
                                'Class of ${person.programYear}',
                              if (!person.isActive) "hasn't joined yet",
                              ...person.roles
                                  .where(
                                    (r) => r != 'alumni' && r != 'volunteer',
                                  )
                                  .map((r) => labels[r] ?? r),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(person, roles),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              Text('Invitations', style: theme.textTheme.titleMedium),
              FutureBuilder<List<Invite>>(
                future: _invites,
                builder: (context, snapshot) {
                  final invites = snapshot.data;
                  if (invites == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (invites.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No invitations yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final invite in invites)
                        ListTile(
                          key: Key('invite-${invite.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            invite.name.isNotEmpty
                                ? invite.name
                                : (invite.email.isNotEmpty
                                      ? invite.email
                                      : invite.code),
                          ),
                          subtitle: Text(
                            [
                              invite.code,
                              invite.usedBy != null
                                  ? 'joined as ${invite.usedBy}'
                                  : invite.status,
                              if (invite.roles.isNotEmpty)
                                invite.roles
                                    .map((r) => labels[r] ?? r)
                                    .join(', '),
                            ].join(' · '),
                          ),
                          trailing: invite.isOpen
                              ? PopupMenuButton<String>(
                                  onSelected: (value) => switch (value) {
                                    'share' => Share.share(
                                      _inviteMessage(invite),
                                    ),
                                    'revoke' => _revoke(invite),
                                    _ => null,
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share link'),
                                    ),
                                    PopupMenuItem(
                                      value: 'revoke',
                                      child: Text('Revoke'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _inviteMessage(Invite invite) =>
    "You're invited to Emerge Kentucky Alumni! Open ${invite.link} , then "
    'download the app, tap Create account and enter invite code '
    '${invite.code}.';

class _PersonSheet extends StatefulWidget {
  const _PersonSheet({
    required this.person,
    required this.roles,
    required this.service,
  });

  final Person person;
  final List<RoleOption> roles;
  final PeopleService service;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  late Person _person = widget.person;
  bool _changed = false;
  bool _busy = false;

  Future<void> _toggle(RoleOption role, bool grant) async {
    final reason = await _askReason(
      context,
      grant
          ? 'Make ${_person.displayName} ${_article(role.label)} ${role.label}'
          : 'Remove ${role.label} from ${_person.displayName}',
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.service.setRole(
        _person.id,
        role.key,
        grant: grant,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _person = updated;
        _changed = true;
      });
    } catch (e) {
      if (mounted) _say(context, _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final person = _person;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.displayName, style: theme.textTheme.titleLarge),
            Text(
              [
                '@${person.username}',
                if (person.programYear != null)
                  'Class of ${person.programYear}',
                if (person.email.isNotEmpty) person.email,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Roles', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (!person.canChange)
              Text(
                'You can see their roles but not change them: they rank the '
                'same as or above you.',
                style: theme.textTheme.bodySmall,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final role in widget.roles)
                  FilterChip(
                    key: Key('role-${role.key}'),
                    label: Text(role.label),
                    selected: person.roles.contains(role.key),
                    onSelected: !person.canChange || _busy
                        ? null
                        : (on) => _toggle(role, on),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Board members get staff tools (console, graduation tracker, '
              'events, CRM) but not moderation. Granting a role confirms '
              'they meet its requirements; every change is logged.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _article(String label) =>
    'aeiou'.contains(label.toLowerCase()[0]) ? 'an' : 'a';

Future<String?> _askReason(BuildContext context, String title) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: title),
    );

/// Asks why; owns its text field so it outlives the closing animation.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('role-reason'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Why (required)'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.roles, required this.service});

  final List<RoleOption> roles;
  final PeopleService service;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  final Set<String> _roles = {};
  late final Future<List<int>> _years = ProgramService().fetchProgramYears();
  int? _year;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty && _email.text.trim().isEmpty) {
      _say(context, 'Add a name or an email.');
      return;
    }
    setState(() => _saving = true);
    try {
      final invite = await widget.service.createInvite(
        name: _name.text.trim(),
        email: _email.text.trim(),
        programYear: _year,
        roles: _roles.toList(),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(invite);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _say(context, _error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite someone', style: theme.textTheme.titleLarge),
            Text(
              'They get a link with a code to enter when they create their '
              'account. It works once and expires in 14 days.',
              style: theme.textTheme.bodySmall,
            ),
            TextField(
              key: const Key('invite-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              key: const Key('invite-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'We email them the link if you add one.',
              ),
            ),
            FutureBuilder<List<int>>(
              future: _years,
              builder: (context, snapshot) => DropdownButtonFormField<int?>(
                initialValue: _year,
                decoration: const InputDecoration(
                  labelText: 'Class year (optional)',
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  for (final year in snapshot.data ?? const <int>[])
                    DropdownMenuItem<int?>(value: year, child: Text('$year')),
                ],
                onChanged: (value) => setState(() => _year = value),
              ),
            ),
            const SizedBox(height: 12),
            Text('Roles when they join', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final role in widget.roles)
                  FilterChip(
                    key: Key('invite-role-${role.key}'),
                    label: Text(role.label),
                    selected: _roles.contains(role.key),
                    onSelected: (on) => setState(() {
                      on ? _roles.add(role.key) : _roles.remove(role.key);
                    }),
                  ),
              ],
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note for staff (optional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('create-invite'),
                onPressed: _saving ? null : _create,
                child: const Text('Create invite'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCreatedDialog extends StatelessWidget {
  const _InviteCreatedDialog({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('invite-created'),
      title: const Text('Invite ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.email.isNotEmpty
                ? 'We emailed it to ${invite.email}. You can also share it:'
                : 'Send them this link:',
          ),
          const SizedBox(height: 8),
          SelectableText(invite.link, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('Code', style: theme.textTheme.labelMedium),
          SelectableText(invite.code, style: theme.textTheme.headlineSmall),
          if (invite.expiresAt != null)
            Text(
              'Expires ${DateFormat.yMMMd().format(invite.expiresAt!)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.link));
            if (context.mounted) _say(context, 'Link copied.');
          },
          child: const Text('Copy link'),
        ),
        FilledButton.icon(
          key: const Key('share-invite'),
          onPressed: () => Share.share(_inviteMessage(invite)),
          icon: const Icon(Icons.ios_share),
          label: const Text('Share'),
        ),
      ],
    );
  }
}
