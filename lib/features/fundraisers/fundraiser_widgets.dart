import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

IconData fundraiserIcon(String name) => switch (name) {
  'home' => Icons.home_outlined,
  'local_bar' => Icons.local_bar_outlined,
  'live_tv' => Icons.live_tv_outlined,
  'cake' => Icons.cake_outlined,
  'school' => Icons.school_outlined,
  'directions_run' => Icons.directions_run,
  _ => Icons.volunteer_activism_outlined,
};

final _whenFormat = DateFormat('EEE, MMM d · h:mm a');

const previewNote =
    'Preview: fundraisers are not connected to Givebutter yet. The page and '
    'donations appear once Emerge connects its account.';

/// One fundraiser in a list: icon, title, status, progress toward the goal.
class FundraiserCard extends StatelessWidget {
  const FundraiserCard({
    super.key,
    required this.fundraiser,
    required this.onTap,
    this.showSample = false,
  });

  final Fundraiser fundraiser;
  final VoidCallback onTap;
  final bool showSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = fundraiser;
    return Card(
      child: InkWell(
        key: Key('fundraiser-${f.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    child: Icon(fundraiserIcon(f.templateIcon)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: theme.textTheme.titleMedium),
                        Text(
                          [
                            f.templateName,
                            if (f.startsAt != null)
                              _whenFormat.format(f.startsAt!),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: f.percent / 100,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatDollars(f.raisedCents)} of '
                      '${formatDollars(f.goalCents)} · '
                      '${f.donorCount} ${f.donorCount == 1 ? 'donor' : 'donors'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _StatusChip(fundraiser: f),
                  if (showSample && f.isDemo) ...[
                    const SizedBox(width: 6),
                    const _Pill(label: 'Sample'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.fundraiser});

  final Fundraiser fundraiser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (fundraiser.status) {
      'live' => scheme.primaryContainer,
      'pending_review' => scheme.tertiaryContainer,
      'rejected' => scheme.errorContainer,
      _ => scheme.surfaceContainerHighest,
    };
    return _Pill(label: fundraiser.statusLabel, color: color);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

/// Picks a template. Returns null when dismissed.
Future<FundraiserTemplate?> showTemplatePicker(
  BuildContext context,
  FundraiserCatalog catalog,
) {
  return showModalBottomSheet<FundraiserTemplate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Start a fundraiser',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a template. It becomes a campaign on Emerge Kentucky\'s '
            'Givebutter account with your name on it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (catalog.isPreview)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                previewNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final template in catalog.templates)
            Card(
              child: ListTile(
                key: Key('template-${template.key}'),
                leading: Icon(fundraiserIcon(template.icon)),
                title: Text(template.name),
                subtitle: Text(
                  '${template.tagline}\nSuggested goal '
                  '${formatDollars(template.defaultGoalCents)}'
                  '${template.ticketPriceCents == null ? '' : ' · ${formatDollars(template.ticketPriceCents!)} tickets'}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.pop(sheetContext, template),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The form for one template. Returns the draft, or null when dismissed.
Future<FundraiserDraft?> showFundraiserForm(
  BuildContext context, {
  required FundraiserTemplate template,
  required FundraiserCatalog catalog,
  required String hostName,
  int? classYear,
}) {
  return showModalBottomSheet<FundraiserDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FundraiserForm(
      template: template,
      catalog: catalog,
      hostName: hostName,
      classYear: classYear,
    ),
  );
}

class _FundraiserForm extends StatefulWidget {
  const _FundraiserForm({
    required this.template,
    required this.catalog,
    required this.hostName,
    required this.classYear,
  });

  final FundraiserTemplate template;
  final FundraiserCatalog catalog;
  final String hostName;
  final int? classYear;

  @override
  State<_FundraiserForm> createState() => _FundraiserFormState();
}

class _FundraiserFormState extends State<_FundraiserForm> {
  late final _title = TextEditingController(
    text: widget.template.renderTitle(
      host: widget.hostName,
      year: widget.classYear,
    ),
  );
  late final _goal = TextEditingController(
    text: '${widget.template.defaultGoalCents ~/ 100}',
  );
  final _location = TextEditingController();
  final _link = TextEditingController();
  final _message = TextEditingController();
  DateTime? _startsAt;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _goal, _location, _link, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial =
        _startsAt ??
        now.add(const Duration(days: 14)).copyWith(hour: 18, minute: 0);
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final title = _title.text.trim();
    final goalDollars = int.tryParse(_goal.text.trim().replaceAll(',', ''));
    final goalCents = (goalDollars ?? 0) * 100;
    final link = _link.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the fundraiser a title.');
      return;
    }
    if (goalDollars == null ||
        goalCents < widget.catalog.minGoalCents ||
        goalCents > widget.catalog.maxGoalCents) {
      setState(
        () => _error =
            'Goals run from ${formatDollars(widget.catalog.minGoalCents)} to '
            '${formatDollars(widget.catalog.maxGoalCents)}.',
      );
      return;
    }
    if (widget.template.needsDate && _startsAt == null) {
      setState(() => _error = 'Pick a date and time.');
      return;
    }
    if (link.isNotEmpty && !link.startsWith('https://')) {
      setState(() => _error = 'Video links must start with https://');
      return;
    }
    Navigator.pop(
      context,
      FundraiserDraft(
        templateKey: widget.template.key,
        title: title,
        goalCents: goalCents,
        message: _message.text.trim(),
        startsAt: _startsAt,
        endsAt: _startsAt == null || widget.template.durationHours == 0
            ? null
            : _startsAt!.add(Duration(hours: widget.template.durationHours)),
        locationName: _location.text.trim(),
        virtualLink: link,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(fundraiserIcon(template.icon)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(template.name, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            Text(template.tagline, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const Key('fundraiser-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              key: const Key('fundraiser-goal'),
              controller: _goal,
              decoration: const InputDecoration(
                labelText: 'Goal',
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
            if (template.needsDate)
              ListTile(
                key: const Key('fundraiser-when'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _startsAt == null
                      ? 'Pick a date and time'
                      : _whenFormat.format(_startsAt!),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickStart,
              ),
            if (template.campaignType == 'event') ...[
              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Where'),
              ),
              TextField(
                controller: _link,
                decoration: const InputDecoration(
                  labelText: 'Video link (https://, optional)',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
            TextField(
              key: const Key('fundraiser-message'),
              controller: _message,
              decoration: const InputDecoration(
                labelText: 'A note from you (optional)',
                hintText: 'Why Emerge matters to you, what to expect…',
              ),
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            Text(
              widget.catalog.reviewRequired
                  ? 'Emerge staff review member fundraisers before they go '
                        'live. ${widget.catalog.notDeductible}'
                  : widget.catalog.notDeductible,
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('fundraiser-save'),
              onPressed: _submit,
              child: Text(
                widget.catalog.reviewRequired
                    ? 'Submit for review'
                    : 'Start fundraiser',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Catalog → template → form → create. Returns true when one was created.
Future<bool> startFundraiserFlow(
  BuildContext context, {
  required FundraisersService service,
  required String hostName,
  int? classYear,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  late final FundraiserCatalog catalog;
  try {
    catalog = await service.fetchCatalog();
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
  if (!context.mounted) return false;
  final template = await showTemplatePicker(context, catalog);
  if (template == null || !context.mounted) return false;
  final draft = await showFundraiserForm(
    context,
    template: template,
    catalog: catalog,
    hostName: hostName,
    classYear: classYear,
  );
  if (draft == null) return false;
  try {
    final created = await service.create(draft);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          created.isPending
              ? 'Submitted. Emerge staff will review it soon.'
              : 'Your fundraiser is live.',
        ),
      ),
    );
    return true;
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

/// Details and actions for one fundraiser: open or share the page, view the
/// event, close it, and (for moderators) approve or reject.
Future<void> showFundraiserSheet(
  BuildContext context, {
  required Fundraiser fundraiser,
  required FundraisersService service,
  required Future<void> Function() onChanged,
  void Function(int eventId)? onOpenEvent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FundraiserSheet(
      fundraiser: fundraiser,
      service: service,
      onChanged: onChanged,
      onOpenEvent: onOpenEvent,
    ),
  );
}

class _FundraiserSheet extends StatefulWidget {
  const _FundraiserSheet({
    required this.fundraiser,
    required this.service,
    required this.onChanged,
    required this.onOpenEvent,
  });

  final Fundraiser fundraiser;
  final FundraisersService service;
  final Future<void> Function() onChanged;
  final void Function(int eventId)? onOpenEvent;

  @override
  State<_FundraiserSheet> createState() => _FundraiserSheetState();
}

class _FundraiserSheetState extends State<_FundraiserSheet> {
  late Fundraiser _f = widget.fundraiser;
  bool _busy = false;

  Future<void> _apply(Future<Fundraiser> Function() call) async {
    setState(() => _busy = true);
    try {
      final updated = await call();
      if (mounted) setState(() => _f = updated);
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _note(String title, String action) => showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('review-note'),
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Note for the host (optional)',
          ),
          maxLines: 3,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(action),
          ),
        ],
      );
    },
  );

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close this fundraiser?'),
        content: const Text(
          'Donations stop and the page comes down. The calendar event, if '
          'there is one, stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close fundraiser'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _apply(() => widget.service.close(_f.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = _f;
    final preview = f.givebutterMode != 'live';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(f.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(fundraiser: f),
                Text(f.templateName, style: theme.textTheme.bodySmall),
                if (f.host != null)
                  Text(
                    'Hosted by ${f.host!.displayName}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (f.startsAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        _whenFormat.format(f.startsAt!),
                        if (f.isVirtual)
                          'Online'
                        else if (f.locationName.isNotEmpty)
                          f.locationName,
                      ].join(' · '),
                    ),
                  ),
                ],
              ),
            ],
            if (f.message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(f.message),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: f.percent / 100,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatDollars(f.raisedCents)} raised of '
              '${formatDollars(f.goalCents)} · ${f.donorCount} '
              '${f.donorCount == 1 ? 'donor' : 'donors'}'
              '${f.ticketPriceCents == null ? '' : ' · ${formatDollars(f.ticketPriceCents!)} tickets'}',
            ),
            if (f.reviewNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Note from Emerge: ${f.reviewNote}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (f.hasPage)
              FilledButton.icon(
                key: const Key('open-givebutter'),
                onPressed: () => launchUrl(
                  Uri.parse(f.givebutterUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open the Givebutter page'),
              )
            else if (f.isLive && preview)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$previewNote\n\nPlanned page: givebutter.com/'
                  '${f.givebutterSlug.isEmpty ? '…' : f.givebutterSlug}',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (f.isLive)
                  OutlinedButton.icon(
                    key: const Key('share-fundraiser'),
                    onPressed: () => Share.share(
                      f.hasPage
                          ? '${f.title}\n${f.givebutterUrl}'
                          : '${f.title} — a fundraiser for Emerge Kentucky. '
                                'Link coming soon.',
                      subject: f.title,
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                if (f.eventId != null && widget.onOpenEvent != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenEvent!(f.eventId!);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('View event'),
                  ),
                if (f.canManage && f.isOpen)
                  TextButton.icon(
                    key: const Key('close-fundraiser'),
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Close fundraiser'),
                  ),
              ],
            ),
            if (f.canReview) ...[
              const Divider(height: 24),
              Text('Review', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('approve-fundraiser'),
                      onPressed: _busy
                          ? null
                          : () async {
                              final note = await _note(
                                'Approve and go live?',
                                'Approve',
                              );
                              if (note != null) {
                                await _apply(
                                  () =>
                                      widget.service.approve(f.id, note: note),
                                );
                              }
                            },
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('reject-fundraiser'),
                      onPressed: _busy
                          ? null
                          : () async {
                              final note = await _note(
                                'Send it back?',
                                'Reject',
                              );
                              if (note != null) {
                                await _apply(
                                  () => widget.service.reject(f.id, note: note),
                                );
                              }
                            },
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
