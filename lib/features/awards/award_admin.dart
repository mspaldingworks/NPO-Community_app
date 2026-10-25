import 'package:flutter/material.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/awards/award_widgets.dart';
import 'package:npo_community/features/awards/awards_service.dart';

void _say(BuildContext context, String message) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(message)));

String _error(Object error) =>
    error is ApiClientException ? error.message : '$error';

/// The control console's Awards tab: every award, retired ones included,
/// with buttons to design a new one, give one to members, see who holds
/// one, and edit or retire it.
class AwardsAdminTab extends StatefulWidget {
  const AwardsAdminTab({super.key, required this.service});

  final AwardsService service;

  @override
  State<AwardsAdminTab> createState() => _AwardsAdminTabState();
}

class _AwardsAdminTabState extends State<AwardsAdminTab>
    with AutomaticKeepAliveClientMixin {
  late Future<AwardCatalog> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<AwardCatalog> _load() =>
      widget.service.fetchCatalog(includeRetired: true);

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _edit([Award? award]) async {
    final saved = await Navigator.of(context).push<Award>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            AwardEditorScreen(service: widget.service, award: award),
      ),
    );
    if (saved != null) await _reload();
  }

  Future<void> _give(Award award) async {
    final given = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GrantAwardScreen(service: widget.service, award: award),
      ),
    );
    if (given != null && mounted) {
      _say(
        context,
        given == 0
            ? 'Everyone chosen already holds ${award.name}.'
            : 'Gave ${award.name} to $given '
                  '${given == 1 ? 'member' : 'members'}.',
      );
      await _reload();
    }
  }

  Future<void> _holders(Award award) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AwardHoldersScreen(service: widget.service, award: award),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<AwardCatalog>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        _error(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator());
          }
          final awards = snapshot.data!.awards;
          return ListView(
            key: const Key('awards-admin-list'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Automatic awards go to members as they reach the goal. '
                      'Give the others by hand, with a note saying why.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('new-award'),
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('New award'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final award in awards)
                Card(
                  key: Key('admin-award-${award.key}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AwardBadge(
                              award: award,
                              size: 44,
                              locked: !award.isActive,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    award.isActive
                                        ? award.name
                                        : '${award.name} (retired)',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  Text(
                                    [
                                      award.automatic
                                          ? 'Automatic: ${award.goal}'
                                          : 'Given by hand',
                                      '${award.holders} '
                                          '${award.holders == 1 ? 'holder' : 'holders'}',
                                    ].join(' · '),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          children: [
                            if (award.isActive)
                              TextButton.icon(
                                onPressed: () => _give(award),
                                icon: const Icon(Icons.card_giftcard, size: 18),
                                label: const Text('Give'),
                              ),
                            TextButton.icon(
                              onPressed: () => _holders(award),
                              icon: const Icon(Icons.people_outline, size: 18),
                              label: const Text('Holders'),
                            ),
                            TextButton.icon(
                              onPressed: () => _edit(award),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Design a new award or edit one: name, description, look, category, and
/// whether it is given by hand or earned automatically on a rule.
class AwardEditorScreen extends StatefulWidget {
  const AwardEditorScreen({super.key, required this.service, this.award});

  final AwardsService service;
  final Award? award;

  @override
  State<AwardEditorScreen> createState() => _AwardEditorScreenState();
}

class _AwardEditorScreenState extends State<AwardEditorScreen> {
  late final Future<AwardOptions> _options = widget.service.fetchOptions();
  late final TextEditingController _name = TextEditingController(
    text: widget.award?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.award?.description ?? '',
  );
  late final TextEditingController _threshold = TextEditingController(
    text: widget.award?.threshold?.toString() ?? '',
  );
  late String _icon = widget.award?.icon ?? 'star';
  late String _color = widget.award?.color ?? hexFromColor(awardColors.first);
  late String _category = widget.award?.category ?? 'special';
  late String _rule = widget.award?.rule ?? '';
  late bool _active = widget.award?.isActive ?? true;
  bool _saving = false;

  bool get _creating => widget.award == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Award get _preview =>
      Award(id: 0, key: '', name: _name.text, icon: _icon, color: _color);

  Future<void> _save() async {
    final threshold = int.tryParse(_threshold.text.trim());
    if (_name.text.trim().isEmpty) {
      _say(context, 'Give the award a name.');
      return;
    }
    if (_rule.isNotEmpty && (threshold == null || threshold < 1)) {
      _say(context, 'Automatic awards need a goal of at least 1.');
      return;
    }
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'icon': _icon,
      'color': _color,
      'category': _category,
      'rule': _rule,
      'threshold': _rule.isEmpty ? null : threshold,
      if (!_creating) 'is_active': _active,
    };
    setState(() => _saving = true);
    try {
      final award = _creating
          ? await widget.service.createAward(fields)
          : await widget.service.updateAward(widget.award!.id, fields);
      if (mounted) Navigator.of(context).pop(award);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_creating ? 'New award' : 'Edit award'),
        actions: [
          TextButton(
            key: const Key('save-award'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: FutureBuilder<AwardOptions>(
        future: _options,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(_error(snapshot.error!))
                  : const CircularProgressIndicator(),
            );
          }
          final options = snapshot.data!;
          final rule = options.rules.where((r) => r.key == _rule).firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: AwardBadge(award: _preview, size: 88)),
              const SizedBox(height: 16),
              TextField(
                key: const Key('award-name'),
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                key: const Key('award-description'),
                controller: _description,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What it is for',
                  hintText: 'Shown to members on the award',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: options.categories.containsKey(_category)
                    ? _category
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final entry in options.categories.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in options.icons)
                    ChoiceChip(
                      key: Key('icon-$key'),
                      label: Icon(iconForAward(key), size: 20),
                      tooltip: key,
                      selected: _icon == key,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _icon = key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Color', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final color in awardColors)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = hexFromColor(color)),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: color,
                        child: _color == hexFromColor(color)
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('How it is earned', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Given by hand')),
                  ButtonSegment(value: true, label: Text('Automatically')),
                ],
                selected: {_rule.isNotEmpty},
                onSelectionChanged: (choice) => setState(() {
                  _rule = choice.first
                      ? (options.rules.isEmpty ? '' : options.rules.first.key)
                      : '';
                }),
              ),
              if (_rule.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('award-rule'),
                  initialValue: _rule,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Counts'),
                  items: [
                    for (final r in options.rules)
                      DropdownMenuItem(value: r.key, child: Text(r.label)),
                  ],
                  onChanged: (value) => setState(() => _rule = value ?? _rule),
                ),
                if (rule != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _rule.startsWith('current_class') &&
                            options.currentClassYear != null
                        ? '${rule.description} The newest class is the Class '
                              'of ${options.currentClassYear}; its own members '
                              "don't earn these."
                        : rule.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  key: const Key('award-threshold'),
                  controller: _threshold,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Goal',
                    suffixText: rule?.unit,
                    helperText:
                        'Members reaching it get the award, including anyone '
                        'who already has.',
                  ),
                ),
              ],
              if (!_creating) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Retired awards stay on the profiles of those who hold '
                    'them, and are no longer given.',
                  ),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Give an award to members chosen by search, with an optional note on why.
/// Pops with how many members received it.
class GrantAwardScreen extends StatefulWidget {
  const GrantAwardScreen({
    super.key,
    required this.service,
    required this.award,
  });

  final AwardsService service;
  final Award award;

  @override
  State<GrantAwardScreen> createState() => _GrantAwardScreenState();
}

class _GrantAwardScreenState extends State<GrantAwardScreen> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _citation = TextEditingController();
  final Map<int, AwardMember> _chosen = {};
  List<AwardMember> _results = const [];
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _citation.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() => _searching = true);
    try {
      final results = await widget.service.searchMembers(_search.text.trim());
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) _say(context, _error(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _give() async {
    setState(() => _saving = true);
    try {
      final grants = await widget.service.grantAward(
        widget.award.id,
        _chosen.keys.toList(),
        citation: _citation.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(grants.length);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Give ${widget.award.name}'),
        actions: [
          TextButton(
            key: const Key('give-award'),
            onPressed: _chosen.isEmpty || _saving ? null : _give,
            child: Text(_chosen.isEmpty ? 'Give' : 'Give (${_chosen.length})'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('award-citation'),
            controller: _citation,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Why (optional)',
              hintText: 'For 40 hours of phone banking in October',
              helperText: 'Shown with the award on their profile.',
            ),
          ),
          if (_chosen.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final member in _chosen.values)
                  InputChip(
                    label: Text(member.displayName),
                    onDeleted: () => setState(() => _chosen.remove(member.id)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('award-member-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _find(),
            decoration: InputDecoration(
              labelText: 'Find members',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _find,
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final member in _results)
            CheckboxListTile(
              key: Key('member-${member.id}'),
              contentPadding: EdgeInsets.zero,
              value: _chosen.containsKey(member.id),
              title: Text(member.displayName),
              subtitle: Text(
                [
                  if (member.programYear != null)
                    'Class of ${member.programYear}',
                  if (!member.isActive) 'has not joined yet',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              onChanged: (on) => setState(() {
                if (on == true) {
                  _chosen[member.id] = member;
                } else {
                  _chosen.remove(member.id);
                }
              }),
            ),
        ],
      ),
    );
  }
}

/// Everyone who holds an award, with why, and a way to take it back.
class AwardHoldersScreen extends StatefulWidget {
  const AwardHoldersScreen({
    super.key,
    required this.service,
    required this.award,
  });

  final AwardsService service;
  final Award award;

  @override
  State<AwardHoldersScreen> createState() => _AwardHoldersScreenState();
}

class _AwardHoldersScreenState extends State<AwardHoldersScreen> {
  late Future<List<AwardGrant>> _future = _load();

  Future<List<AwardGrant>> _load() =>
      widget.service.fetchHolders(widget.award.id);

  Future<void> _revoke(AwardGrant grant) async {
    final name = grant.account?.displayName ?? 'this member';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Take back ${widget.award.name}?'),
        content: Text(
          'It comes off $name\'s profile.'
          '${grant.automatic ? ' They will not earn it again automatically.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Take back'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.revokeGrant(grant.id);
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
    } catch (e) {
      if (mounted) _say(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.award.name}: holders')),
      body: FutureBuilder<List<AwardGrant>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(_error(snapshot.error!))
                  : const CircularProgressIndicator(),
            );
          }
          final grants = snapshot.data!;
          if (grants.isEmpty) {
            return const Center(child: Text('Nobody holds this award yet.'));
          }
          return ListView(
            children: [
              for (final grant in grants)
                ListTile(
                  key: Key('holder-${grant.id}'),
                  title: Text(grant.account?.displayName ?? 'Member'),
                  subtitle: Text(
                    [
                      if (grant.citation.isNotEmpty) grant.citation,
                      grant.automatic
                          ? 'Earned automatically'
                          : 'Given by ${grant.grantedBy ?? 'an administrator'}',
                    ].join('\n'),
                  ),
                  isThreeLine: grant.citation.isNotEmpty,
                  trailing: IconButton(
                    tooltip: 'Take back',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _revoke(grant),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
