import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/events/events_service.dart';

/// Bottom sheet for creating or editing an event. Calls [onSubmit] with the
/// draft and returns true when it succeeded.
Future<bool> showEventForm(
  BuildContext context, {
  required Future<void> Function(EventDraft draft) onSubmit,
  String title = 'New event',
  CommunityEvent? initial,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _EventForm(onSubmit: onSubmit, title: title, initial: initial),
  );
  return result == true;
}

class _EventForm extends StatefulWidget {
  const _EventForm({
    required this.onSubmit,
    required this.title,
    required this.initial,
  });

  final Future<void> Function(EventDraft draft) onSubmit;
  final String title;
  final CommunityEvent? initial;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _location = TextEditingController(
    text: widget.initial?.locationName ?? '',
  );
  late final _link = TextEditingController(
    text: widget.initial?.virtualLink ?? '',
  );
  late final _capacity = TextEditingController(
    text: widget.initial?.capacity?.toString() ?? '',
  );
  late DateTime _startsAt =
      widget.initial?.startsAt ??
      DateTime.now()
          .add(const Duration(days: 7))
          .copyWith(
            hour: 18,
            minute: 0,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          );
  late DateTime? _endsAt = widget.initial?.endsAt;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _description, _location, _link, _capacity]) {
      c.dispose();
    }
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

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a title.');
      return;
    }
    if (_endsAt != null && _endsAt!.isBefore(_startsAt)) {
      setState(() => _error = 'The end must be after the start.');
      return;
    }
    final link = _link.text.trim();
    if (link.isNotEmpty && !link.startsWith('https://')) {
      setState(() => _error = 'Video links must start with https://');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        EventDraft(
          title: title,
          startsAt: _startsAt,
          endsAt: _endsAt,
          description: _description.text.trim(),
          locationName: _location.text.trim(),
          virtualLink: link,
          capacity: int.tryParse(_capacity.text.trim()),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
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
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('event-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('Starts ${format.format(_startsAt)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await _pick(_startsAt);
                if (picked != null) setState(() => _startsAt = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(
                _endsAt == null
                    ? 'Ends: not set'
                    : 'Ends ${format.format(_endsAt!)}',
              ),
              trailing: _endsAt == null
                  ? const Icon(Icons.add)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endsAt = null),
                    ),
              onTap: () async {
                final picked = await _pick(
                  _endsAt ?? _startsAt.add(const Duration(hours: 2)),
                );
                if (picked != null) setState(() => _endsAt = picked);
              },
            ),
            TextField(
              key: const Key('event-location'),
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Video link (https://, optional)',
              ),
              keyboardType: TextInputType.url,
            ),
            TextField(
              controller: _capacity,
              decoration: const InputDecoration(
                labelText: 'Capacity (optional)',
                hintText: 'Leave blank for unlimited',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Details'),
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('event-save'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
