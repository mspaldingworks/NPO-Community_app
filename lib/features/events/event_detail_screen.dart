import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/events/event_form.dart';
import 'package:npo_community/features/events/events_screen.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/events/ics.dart';
import 'package:url_launcher/url_launcher.dart';

/// One event: when and where, RSVP, volunteer shifts, add-to-calendar, and
/// organizer tools (edit, shifts, roster and check-in, cancel) for those who
/// can manage it.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.service,
    this.now,
  });

  final int eventId;

  /// Injected in tests.
  final EventsService? service;

  /// Clock override for tests.
  final DateTime Function()? now;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventsService _service = widget.service ?? EventsService();
  CommunityEvent? _event;
  Object? _error;
  bool _busy = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final event = await _service.fetchEvent(widget.eventId);
      if (mounted) {
        setState(() {
          _event = event;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs a call that returns the refreshed event, surfacing failures as a
  /// snackbar so the page never gets stuck.
  Future<void> _apply(Future<CommunityEvent> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final event = await call();
      if (mounted) setState(() => _event = event);
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

  Future<void> _edit(CommunityEvent event) async {
    await showEventForm(
      context,
      title: 'Edit event',
      initial: event,
      onSubmit: (draft) async {
        final updated = await _service.updateEvent(event.id, draft.toJson());
        if (mounted) setState(() => _event = updated);
      },
    );
  }

  Future<void> _cancel(CommunityEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'Everyone who RSVPed will see it marked cancelled. Sign-ups close.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apply(
        () => _service.updateEvent(event.id, {'is_cancelled': true}),
      );
    }
  }

  Future<void> _addShift(CommunityEvent event) async {
    final shift = await showModalBottomSheet<_ShiftDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShiftForm(event: event),
    );
    if (shift == null) return;
    await _apply(
      () => _service.addShift(
        event.id,
        roleName: shift.roleName,
        startsAt: shift.startsAt,
        endsAt: shift.endsAt,
        slots: shift.slots,
        description: shift.description,
      ),
    );
  }

  Future<void> _roster(CommunityEvent event) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RosterSheet(event: event, service: _service),
  );

  Future<void> _share(CommunityEvent event) async {
    try {
      await shareIcs(event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not open the share sheet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      appBar: AppBar(
        title: Text(event?.title ?? 'Event'),
        actions: [
          if (event != null && event.canManage)
            PopupMenuButton<String>(
              key: const Key('organizer-menu'),
              tooltip: 'Organizer tools',
              onSelected: (value) => switch (value) {
                'edit' => _edit(event),
                'shift' => _addShift(event),
                'roster' => _roster(event),
                'cancel' => _cancel(event),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit event')),
                const PopupMenuItem(
                  value: 'shift',
                  child: Text('Add volunteer shift'),
                ),
                const PopupMenuItem(
                  value: 'roster',
                  child: Text('Roster & check-in'),
                ),
                if (!event.isCancelled)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel event'),
                  ),
              ],
            ),
        ],
      ),
      body: event == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$_error', textAlign: TextAlign.center),
                    ),
            )
          : RefreshIndicator(onRefresh: _load, child: _body(context, event)),
    );
  }

  Widget _body(BuildContext context, CommunityEvent event) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = _now;
    final over = !isUpcoming(event, now);
    final closed = event.isCancelled || over;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (event.isCancelled)
          _Banner(
            icon: Icons.event_busy_outlined,
            text: 'This event was cancelled.',
            color: scheme.errorContainer,
            onColor: scheme.onErrorContainer,
          )
        else if (over)
          _Banner(
            icon: Icons.history,
            text: 'This event has ended.',
            color: scheme.surfaceContainerHighest,
            onColor: scheme.onSurfaceVariant,
          ),
        Text(event.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(event.scopeLabel),
              visualDensity: VisualDensity.compact,
            ),
            if (event.isDemo && event.canManage)
              const Chip(
                label: Text('Sample'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Line(
          icon: Icons.schedule,
          text: formatWhen(event.startsAt, event.endsAt),
        ),
        if (event.isVirtual)
          _Line(
            icon: Icons.videocam_outlined,
            text: 'Virtual',
            trailing: event.virtualLink.isEmpty
                ? null
                : TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(event.virtualLink),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Join'),
                  ),
          )
        else if (event.locationName.isNotEmpty)
          _Line(icon: Icons.place_outlined, text: event.locationName),
        _Line(
          icon: Icons.people_outline,
          text: [
            '${event.goingCount} going',
            if (event.maybeCount > 0) '${event.maybeCount} maybe',
            if (event.capacity != null) 'capacity ${event.capacity}',
          ].join(' · '),
        ),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(event.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        Text('Are you coming?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const Key('rsvp'),
          segments: const [
            ButtonSegment(
              value: 'going',
              label: Text('Going'),
              icon: Icon(Icons.check),
            ),
            ButtonSegment(value: 'maybe', label: Text('Maybe')),
            ButtonSegment(value: 'declined', label: Text("Can't")),
          ],
          selected: {if (event.myRsvp != null) event.myRsvp!},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: closed || _busy
              ? null
              : (selection) {
                  if (selection.isEmpty) return;
                  _apply(() => _service.rsvp(event.id, selection.first));
                },
        ),
        if (event.isFull && event.myRsvp != 'going' && !closed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'This event is full. You can still mark Maybe.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('add-to-calendar'),
              onPressed: () => _share(event),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Add to calendar'),
            ),
          ],
        ),
        if (event.shifts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Volunteer shifts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Claim a shift and we count you as going.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final shift in event.shifts)
            Card(
              child: ListTile(
                key: Key('shift-${shift.id}'),
                leading: Icon(
                  shift.myClaim
                      ? Icons.volunteer_activism
                      : Icons.volunteer_activism_outlined,
                  color: shift.myClaim ? scheme.primary : null,
                ),
                title: Text(shift.roleName),
                subtitle: Text(
                  [
                    formatWhen(shift.startsAt, shift.endsAt),
                    shift.isFull
                        ? 'Full (${shift.slots})'
                        : '${shift.openSlots} of ${shift.slots} open',
                    if (shift.description.isNotEmpty) shift.description,
                  ].join('\n'),
                ),
                isThreeLine: shift.description.isNotEmpty,
                trailing: _shiftButton(event, shift, closed, now),
              ),
            ),
        ],
        if (event.canManage) ...[
          const SizedBox(height: 24),
          Text('Organizer tools', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _roster(event),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Roster & check-in'),
              ),
              FilledButton.tonalIcon(
                key: const Key('add-shift'),
                onPressed: event.isCancelled ? null : () => _addShift(event),
                icon: const Icon(Icons.add),
                label: const Text('Add shift'),
              ),
              OutlinedButton.icon(
                onPressed: () => _edit(event),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _shiftButton(
    CommunityEvent event,
    VolunteerShift shift,
    bool closed,
    DateTime now,
  ) {
    if (shift.myClaim) {
      return TextButton(
        key: Key('release-${shift.id}'),
        onPressed: _busy
            ? null
            : () => _apply(() => _service.releaseShift(event.id, shift.id)),
        child: const Text('Release'),
      );
    }
    if (closed || !shift.endsAt.isAfter(now)) return null;
    if (shift.isFull) return const Text('Full');
    return FilledButton(
      key: Key('claim-${shift.id}'),
      onPressed: _busy
          ? null
          : () => _apply(() => _service.claimShift(event.id, shift.id)),
      child: const Text('Sign up'),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: onColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: onColor)),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
        ?trailing,
      ],
    ),
  );
}

class _ShiftDraft {
  const _ShiftDraft({
    required this.roleName,
    required this.startsAt,
    required this.endsAt,
    required this.slots,
    required this.description,
  });

  final String roleName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int slots;
  final String description;
}

class _ShiftForm extends StatefulWidget {
  const _ShiftForm({required this.event});

  final CommunityEvent event;

  @override
  State<_ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<_ShiftForm> {
  final _role = TextEditingController();
  final _slots = TextEditingController(text: '1');
  final _description = TextEditingController();
  late DateTime _startsAt = widget.event.startsAt;
  late DateTime _endsAt =
      widget.event.endsAt ??
      widget.event.startsAt.add(const Duration(hours: 2));
  String? _error;

  @override
  void dispose() {
    _role.dispose();
    _slots.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: initial,
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  void _submit() {
    final role = _role.text.trim();
    final slots = int.tryParse(_slots.text.trim()) ?? 0;
    if (role.isEmpty) {
      setState(() => _error = 'Name the role, e.g. Greeter.');
      return;
    }
    if (slots < 1) {
      setState(() => _error = 'Slots must be at least 1.');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'The shift must end after it starts.');
      return;
    }
    Navigator.pop(
      context,
      _ShiftDraft(
        roleName: role,
        startsAt: _startsAt,
        endsAt: _endsAt,
        slots: slots,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('EEE, MMM d · h:mm a');
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
            Text('New volunteer shift', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('shift-role'),
              controller: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                hintText: 'Greeter, Check-in table, Panelist…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              key: const Key('shift-slots'),
              controller: _slots,
              decoration: const InputDecoration(labelText: 'Slots'),
              keyboardType: TextInputType.number,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('Starts ${format.format(_startsAt)}'),
              onTap: () async {
                final picked = await _pick(_startsAt);
                if (picked != null) setState(() => _startsAt = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text('Ends ${format.format(_endsAt)}'),
              onTap: () async {
                final picked = await _pick(_endsAt);
                if (picked != null) setState(() => _endsAt = picked);
              },
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'What they will do (optional)',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('shift-save'),
              onPressed: _submit,
              child: const Text('Add shift'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who said they're coming, which shifts they claimed, and a check-in box
/// per person. Check-ins count toward their volunteer hours.
class _RosterSheet extends StatefulWidget {
  const _RosterSheet({required this.event, required this.service});

  final CommunityEvent event;
  final EventsService service;

  @override
  State<_RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends State<_RosterSheet> {
  late Future<List<RosterRow>> _rows = widget.service.fetchRoster(
    widget.event.id,
  );

  Future<void> _toggle(RosterRow row, bool attended) async {
    final updated = widget.service.checkIn(
      widget.event.id,
      row.id,
      attended: attended,
    );
    setState(() {
      _rows = updated;
    });
    try {
      await updated;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$e')));
        setState(() {
          _rows = widget.service.fetchRoster(widget.event.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => FutureBuilder<List<RosterRow>>(
        future: _rows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text('${snapshot.error}')
                  : const CircularProgressIndicator(),
            );
          }
          final rows = snapshot.data!;
          final attended = rows.where((r) => r.attended).length;
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Roster', style: theme.textTheme.titleLarge),
              Text(
                '${rows.length} on the list · $attended checked in',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Nobody has RSVPed yet.'),
                ),
              for (final row in rows)
                CheckboxListTile(
                  key: Key('roster-${row.id}'),
                  value: row.attended,
                  onChanged: (value) => _toggle(row, value ?? false),
                  title: Text(row.displayName),
                  subtitle: Text(
                    [
                      row.status,
                      if (row.shifts.isNotEmpty) row.shifts.join(', '),
                    ].join(' · '),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          );
        },
      ),
    );
  }
}
