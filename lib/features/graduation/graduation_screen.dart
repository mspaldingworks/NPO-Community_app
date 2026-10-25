import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/awards/awards_service.dart';
import 'package:npo_community/features/graduation/graduation_service.dart';
import 'package:npo_community/theme/app_theme.dart';

void _say(BuildContext context, String message) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(message)));

String _error(Object error) =>
    error is ApiClientException ? error.message : '$error';

enum _Filter { all, behind, complete }

/// The graduation tracker for staff and administrators: every member of a
/// class (the current one by default) against every requirement, with how
/// many have met each. A member opens their page, where staff edit progress.
class GraduationScreen extends StatefulWidget {
  const GraduationScreen({
    super.key,
    this.service,
    this.awards,
    this.canGiveAwards = false,
  });

  /// Injected in tests.
  final GraduationService? service;
  final AwardsService? awards;

  /// Administrators can give the Emerge Graduate award from a member's page.
  final bool canGiveAwards;

  @override
  State<GraduationScreen> createState() => _GraduationScreenState();
}

class _GraduationScreenState extends State<GraduationScreen> {
  late final GraduationService _service = widget.service ?? GraduationService();
  int? _year;
  late Future<GraduationOverview> _future = _service.fetchOverview();
  _Filter _filter = _Filter.all;
  String _search = '';

  Future<void> _reload() async {
    final future = _service.fetchOverview(year: _year);
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  void _pickYear(int year) {
    _year = year;
    _reload();
  }

  Future<void> _openMember(GradMember member) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GraduationMemberScreen(
          memberId: member.id,
          service: _service,
          awards: widget.awards,
          canGiveAwards: widget.canGiveAwards,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openRequirements() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GraduationRequirementsScreen(service: _service),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graduation tracker'),
        actions: [
          IconButton(
            key: const Key('edit-requirements'),
            tooltip: 'Edit requirements',
            icon: const Icon(Icons.checklist),
            onPressed: _openRequirements,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<GraduationOverview>(
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
            return _overview(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _overview(GraduationOverview data) {
    final theme = Theme.of(context);
    final query = _search.toLowerCase();
    final members = [
      for (final m in data.members)
        if ((_filter == _Filter.all ||
                (_filter == _Filter.complete) == m.complete) &&
            (query.isEmpty || m.displayName.toLowerCase().contains(query)))
          m,
    ];
    return ListView(
      key: const Key('graduation-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Class of ${data.year}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            PopupMenuButton<int>(
              key: const Key('graduation-year'),
              tooltip: 'Choose a class',
              initialValue: data.year,
              onSelected: _pickYear,
              itemBuilder: (_) => [
                for (final year in data.years)
                  PopupMenuItem(value: year, child: Text('Class of $year')),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Other classes'),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
        Text(
          '${data.complete} of ${data.members.length} '
          'have met every requirement',
          key: const Key('graduation-summary'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final r in data.requirements)
              Chip(
                label: Text(
                  '${r.name}: ${data.metByRequirement[r.id] ?? 0} of '
                  '${data.members.length} '
                  '(goal ${formatAmount(r.target, r.unit)})',
                ),
              ),
          ],
        ),
        if (data.fundraisingSample) ...[
          const SizedBox(height: 8),
          const _SampleNote(),
        ],
        if (!data.fundraisingAvailable) ...[
          const SizedBox(height: 8),
          const Text(
            'Givebutter could not be reached; fundraising shows \$0 until '
            'it can.',
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('graduation-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Find a member',
          ),
          onChanged: (value) => setState(() => _search = value.trim()),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_Filter>(
          segments: const [
            ButtonSegment(value: _Filter.all, label: Text('Everyone')),
            ButtonSegment(value: _Filter.behind, label: Text('Not done')),
            ButtonSegment(value: _Filter.complete, label: Text('Complete')),
          ],
          selected: {_filter},
          onSelectionChanged: (choice) =>
              setState(() => _filter = choice.first),
        ),
        const SizedBox(height: 12),
        if (data.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nobody is in this class yet.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final member in members)
          _MemberCard(
            member: member,
            requirements: data.requirements,
            onTap: () => _openMember(member),
          ),
      ],
    );
  }
}

class _SampleNote extends StatelessWidget {
  const _SampleNote();

  @override
  Widget build(BuildContext context) => const Card(
    key: Key('graduation-sample'),
    color: AppColors.alertBackground,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Fundraising shows sample amounts until Givebutter is connected. '
        'Use adjustments only for money raised outside Givebutter.',
      ),
    ),
  );
}

/// A requirement's bar: met is green, waived says so.
class GradBar extends StatelessWidget {
  const GradBar({super.key, required this.status, required this.requirement});

  final GradStatus status;
  final GradRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final color = status.met ? AppColors.green : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: status.waived ? 1 : status.fraction,
            minHeight: 8,
            color: status.waived ? Colors.grey : color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status.waived
              ? 'Waived'
              : '${formatAmount(status.value, requirement.unit)} of '
                    '${formatAmount(status.target, requirement.unit)}'
                    '${status.met ? ' ✓' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.requirements,
    required this.onTap,
  });

  final GradMember member;
  final List<GradRequirement> requirements;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('graduation-member-${member.id}'),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      member.joined
                          ? member.displayName
                          : '${member.displayName} (not joined yet)',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: member.complete
                        ? AppColors.green.withValues(alpha: 0.2)
                        : null,
                    label: Text(
                      member.complete
                          ? 'Complete'
                          : '${member.met} of ${member.total} met',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < requirements.length; i++)
                if (i < member.requirements.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            requirements[i].name,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: GradBar(
                            status: member.requirements[i],
                            requirement: requirements[i],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One class member: each requirement with how the number is made up
/// (automatic + staff adjustment), the last note, an Edit button, and the
/// edit history.
class GraduationMemberScreen extends StatefulWidget {
  const GraduationMemberScreen({
    super.key,
    required this.memberId,
    required this.service,
    this.awards,
    this.canGiveAwards = false,
  });

  final int memberId;
  final GraduationService service;
  final AwardsService? awards;
  final bool canGiveAwards;

  @override
  State<GraduationMemberScreen> createState() => _GraduationMemberScreenState();
}

class _GraduationMemberScreenState extends State<GraduationMemberScreen> {
  late Future<GradMemberDetail> _future = widget.service.fetchMember(
    widget.memberId,
  );

  void _show(GradMemberDetail detail) {
    setState(() {
      _future = Future.value(detail);
    });
  }

  Future<void> _edit(
    GradMemberDetail detail,
    GradRequirement requirement,
    GradStatus status,
  ) async {
    final updated = await showModalBottomSheet<GradMemberDetail>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProgressSheet(
        service: widget.service,
        memberId: widget.memberId,
        requirement: requirement,
        status: status,
      ),
    );
    if (updated != null && mounted) _show(updated);
  }

  Future<void> _giveGraduateAward(GradMember member) async {
    final awards = widget.awards ?? AwardsService();
    try {
      final catalog = await awards.fetchCatalog();
      final graduate = catalog.awards
          .where((a) => a.key == 'emerge-graduate')
          .firstOrNull;
      if (graduate == null) {
        if (mounted) _say(context, 'The Emerge Graduate award is retired.');
        return;
      }
      final given = await awards.grantAward(graduate.id, [member.id]);
      if (mounted) {
        _say(
          context,
          given.isEmpty
              ? '${member.displayName} already has it.'
              : 'Gave ${member.displayName} the Emerge Graduate award.',
        );
      }
    } catch (e) {
      if (mounted) _say(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GradMemberDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(detail?.member.displayName ?? 'Member')),
          body: detail == null
              ? Center(
                  child: snapshot.hasError
                      ? Text(_error(snapshot.error!))
                      : const CircularProgressIndicator(),
                )
              : _body(detail),
        );
      },
    );
  }

  Widget _body(GradMemberDetail detail) {
    final theme = Theme.of(context);
    final member = detail.member;
    return ListView(
      key: const Key('graduation-member'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Class of ${detail.programYear}'
          '${member.joined ? '' : ' · has not joined the app yet'}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          member.complete
              ? 'Every requirement met'
              : '${member.met} of ${member.total} requirements met',
          style: theme.textTheme.titleMedium,
        ),
        if (member.complete && widget.canGiveAwards) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('give-graduate'),
              onPressed: () => _giveGraduateAward(member),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Give the Emerge Graduate award'),
            ),
          ),
        ],
        if (detail.fundraisingSample) ...[
          const SizedBox(height: 8),
          const _SampleNote(),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < detail.requirements.length; i++)
          if (i < member.requirements.length)
            _RequirementCard(
              requirement: detail.requirements[i],
              status: member.requirements[i],
              onEdit: () =>
                  _edit(detail, detail.requirements[i], member.requirements[i]),
            ),
        if (detail.history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Edit history', style: theme.textTheme.titleMedium),
          for (final entry in detail.history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(entry.notes),
              subtitle: Text(
                [
                  if (entry.by != null) entry.by!,
                  if (entry.at != null)
                    DateFormat.yMMMd().add_jm().format(entry.at!),
                ].join(' · '),
              ),
            ),
        ],
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.requirement,
    required this.status,
    required this.onEdit,
  });

  final GradRequirement requirement;
  final GradStatus status;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = requirement.unit;
    final adjustment = status.adjustment;
    return Card(
      key: Key('requirement-${requirement.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    requirement.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (status.met)
                  const Icon(Icons.check_circle, color: AppColors.green),
              ],
            ),
            if (requirement.description.isNotEmpty)
              Text(requirement.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            GradBar(status: status, requirement: requirement),
            const SizedBox(height: 6),
            Text(
              [
                if (!requirement.isManual)
                  'Counted by the app: ${formatAmount(status.automatic, unit)}',
                if (adjustment != 0 || requirement.isManual)
                  'Staff ${requirement.isManual ? 'recorded' : 'adjustment'}: '
                      '${adjustment > 0 && !requirement.isManual ? '+' : ''}'
                      '${formatAmount(adjustment, unit)}',
              ].join(' · '),
              key: Key('breakdown-${requirement.id}'),
              style: theme.textTheme.bodySmall,
            ),
            if (status.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '“${status.note}”'
                '${status.updatedBy == null ? '' : ' (${status.updatedBy}'
                          '${status.updatedAt == null ? '' : ', ${DateFormat.yMMMd().format(status.updatedAt!)}'})'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('edit-progress-${requirement.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit progress'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staff edit one requirement for one member: the amount added to (or
/// taken from) the automatic count, or a waiver, with a required note.
class _EditProgressSheet extends StatefulWidget {
  const _EditProgressSheet({
    required this.service,
    required this.memberId,
    required this.requirement,
    required this.status,
  });

  final GraduationService service;
  final int memberId;
  final GradRequirement requirement;
  final GradStatus status;

  @override
  State<_EditProgressSheet> createState() => _EditProgressSheetState();
}

class _EditProgressSheetState extends State<_EditProgressSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: _plain(widget.status.adjustment),
  );
  final TextEditingController _note = TextEditingController();
  late bool _waived = widget.status.waived;
  bool _saving = false;
  String? _problem;

  static String _plain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null) {
      setState(() => _problem = 'Enter a number (use - to subtract).');
      return;
    }
    if (_note.text.trim().isEmpty) {
      setState(() => _problem = 'Add a note saying why.');
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      final detail = await widget.service.editProgress(
        widget.memberId,
        widget.requirement.id,
        adjustment: amount,
        waived: _waived,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(detail);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _problem = _error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requirement = widget.requirement;
    final manual = requirement.isManual;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requirement.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            manual
                ? 'Record how much of this they have done. Goal: '
                      '${formatAmount(requirement.target, requirement.unit)}.'
                : 'The app counted '
                      '${formatAmount(widget.status.automatic, requirement.unit)}. '
                      'Add credit for work outside the app, or subtract to '
                      'correct the count. Goal: '
                      '${formatAmount(requirement.target, requirement.unit)}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('progress-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: manual ? 'Amount done' : 'Adjustment (+ or -)',
              suffixText: requirement.unit == 'dollars'
                  ? null
                  : requirement.unit,
              prefixText: requirement.unit == 'dollars' ? '\$ ' : null,
            ),
          ),
          SwitchListTile(
            key: const Key('progress-waived'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Waive this requirement'),
            subtitle: const Text('Counts as met regardless of the number.'),
            value: _waived,
            onChanged: _saving ? null : (v) => setState(() => _waived = v),
          ),
          TextField(
            key: const Key('progress-note'),
            controller: _note,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Why (required)',
              hintText: 'Phone banked 3 hours on 10/18; logged on paper',
            ),
          ),
          if (_problem != null)
            Text(
              _problem!,
              key: const Key('progress-problem'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('progress-save'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff and administrators add, edit and retire requirements.
class GraduationRequirementsScreen extends StatefulWidget {
  const GraduationRequirementsScreen({super.key, required this.service});

  final GraduationService service;

  @override
  State<GraduationRequirementsScreen> createState() =>
      _GraduationRequirementsScreenState();
}

class _GraduationRequirementsScreenState
    extends State<GraduationRequirementsScreen> {
  late Future<(List<GradRequirement>, Map<String, String>)> _future = widget
      .service
      .fetchRequirements();

  void _reload() {
    setState(() {
      _future = widget.service.fetchRequirements();
    });
  }

  Future<void> _edit(Map<String, String> sources, [GradRequirement? r]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RequirementEditor(
        service: widget.service,
        sources: sources,
        requirement: r,
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<GradRequirement>, Map<String, String>)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Graduation requirements')),
          floatingActionButton: data == null
              ? null
              : FloatingActionButton.extended(
                  key: const Key('add-requirement'),
                  onPressed: () => _edit(data.$2),
                  icon: const Icon(Icons.add),
                  label: const Text('Add requirement'),
                ),
          body: data == null
              ? Center(
                  child: snapshot.hasError
                      ? Text(_error(snapshot.error!))
                      : const CircularProgressIndicator(),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  children: [
                    for (final r in data.$1)
                      Card(
                        child: ListTile(
                          key: Key('requirement-row-${r.id}'),
                          title: Text(
                            r.isActive ? r.name : '${r.name} (retired)',
                          ),
                          subtitle: Text(
                            'Goal: ${formatAmount(r.target, r.unit)} · '
                            '${r.sourceLabel}',
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => _edit(data.$2, r),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _RequirementEditor extends StatefulWidget {
  const _RequirementEditor({
    required this.service,
    required this.sources,
    this.requirement,
  });

  final GraduationService service;
  final Map<String, String> sources;
  final GradRequirement? requirement;

  @override
  State<_RequirementEditor> createState() => _RequirementEditorState();
}

class _RequirementEditorState extends State<_RequirementEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.requirement?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.requirement?.description ?? '',
  );
  late final TextEditingController _target = TextEditingController(
    text: widget.requirement == null
        ? '1'
        : _EditProgressSheetState._plain(widget.requirement!.target),
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.requirement?.unit ?? '',
  );
  late String _source = widget.requirement?.source ?? 'manual';
  late bool _active = widget.requirement?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(_target.text.trim());
    if (_name.text.trim().isEmpty || target == null || target <= 0) {
      _say(context, 'Give it a name and a goal above zero.');
      return;
    }
    final fields = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'source': _source,
      'target': target,
      'unit': _unit.text.trim(),
      'is_active': _active,
    };
    setState(() => _saving = true);
    try {
      final existing = widget.requirement;
      if (existing == null) {
        await widget.service.createRequirement(fields);
      } else {
        await widget.service.updateRequirement(existing.id, fields);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _say(context, _error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            TextField(
              key: const Key('requirement-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('requirement-source'),
              initialValue: widget.sources.containsKey(_source)
                  ? _source
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Counted from'),
              items: [
                for (final entry in widget.sources.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _source = value ?? _source),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('requirement-target'),
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Goal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('requirement-unit'),
                    controller: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'hours, sessions, dollars',
                    ),
                  ),
                ),
              ],
            ),
            if (widget.requirement != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text(
                  'Retired requirements stop counting toward graduation.',
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('requirement-save'),
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
