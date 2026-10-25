import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:npo_community/core/constants/api_endpoints.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

String _error(Object error) =>
    error is ApiClientException ? error.message : '$error';

void _say(BuildContext context, String message) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(message)));

/// The member's personal check-in code: a QR the organizer scans at the
/// door. Signed by the server; resetting it voids screenshots of the old one.
class MyCheckInCodeScreen extends StatefulWidget {
  const MyCheckInCodeScreen({super.key, this.service, this.name});

  /// Injected in tests.
  final EventsService? service;

  /// Shown under the code so the person scanning can match the name.
  final String? name;

  @override
  State<MyCheckInCodeScreen> createState() => _MyCheckInCodeScreenState();
}

class _MyCheckInCodeScreenState extends State<MyCheckInCodeScreen> {
  late final EventsService _service = widget.service ?? EventsService();
  late Future<String> _code = _service.fetchMyCode();

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get a new code?'),
        content: const Text(
          'Your old code stops working, including any screenshot of it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New code'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _code = _service.fetchMyCode(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My check-in code')),
      body: FutureBuilder<String>(
        future: _code,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(_error(snapshot.error!))
                  : const CircularProgressIndicator(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Show this at the door. The organizer scans it to check you '
                'in, which counts toward your awards.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    key: const Key('my-check-in-qr'),
                    data: snapshot.data!,
                    size: 260,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              if (widget.name != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.name!,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Turn your screen brightness up if it won\'t scan.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Get a new code'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Organizers' check-in for one event: find anyone and tap to check them
/// in (walk-ins included), scan codes with the camera, and the event's CRM
/// lists with counts and CSV export.
class EventCheckInScreen extends StatefulWidget {
  const EventCheckInScreen({super.key, required this.event, this.service});

  final CommunityEvent event;

  /// Injected in tests.
  final EventsService? service;

  @override
  State<EventCheckInScreen> createState() => _EventCheckInScreenState();
}

class _EventCheckInScreenState extends State<EventCheckInScreen> {
  late final EventsService _service = widget.service ?? EventsService();
  final _listsKey = GlobalKey<_ListsTabState>();
  final _checkInKey = GlobalKey<_CheckInTabState>();

  Future<void> _scan() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CheckInScannerScreen(event: widget.event, service: _service),
      ),
    );
    _checkInKey.currentState?.reload();
    _listsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Check-in: ${widget.event.title}'),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('tab-check-in'), text: 'Check in'),
              Tab(key: Key('tab-lists'), text: 'Lists'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('scan-check-ins'),
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'),
        ),
        body: TabBarView(
          children: [
            _CheckInTab(
              key: _checkInKey,
              event: widget.event,
              service: _service,
              onChanged: () => _listsKey.currentState?.reload(),
            ),
            _ListsTab(key: _listsKey, event: widget.event, service: _service),
          ],
        ),
      ),
    );
  }
}

class _CheckInTab extends StatefulWidget {
  const _CheckInTab({
    super.key,
    required this.event,
    required this.service,
    required this.onChanged,
  });

  final CommunityEvent event;
  final EventsService service;
  final VoidCallback onChanged;

  @override
  State<_CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<_CheckInTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '';
  late Future<List<RosterRow>> _rows = _load();

  @override
  bool get wantKeepAlive => true;

  /// The RSVP roster, or everyone matching the search (walk-ins).
  Future<List<RosterRow>> _load() => _query.isEmpty
      ? widget.service.fetchRoster(widget.event.id)
      : widget.service.searchMembers(widget.event.id, _query);

  void reload() => setState(() {
    _rows = _load();
  });

  Future<void> _toggle(RosterRow row) async {
    if (row.attended) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Undo ${row.displayName}\'s check-in?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Undo'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await widget.service.checkIn(
        widget.event.id,
        row.id,
        attended: !row.attended,
      );
      if (!mounted) return;
      _say(
        context,
        row.attended
            ? 'Undid ${row.displayName}\'s check-in.'
            : 'Checked in ${row.displayName}.',
      );
      reload();
      widget.onChanged();
    } catch (e) {
      if (mounted) _say(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const Key('check-in-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Find anyone to check in',
              helperText:
                  'Search everyone, including walk-ins who didn\'t RSVP',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _query = value.trim();
              reload();
            },
            onChanged: (value) {
              if (value.trim().isEmpty && _query.isNotEmpty) {
                _query = '';
                reload();
              }
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RosterRow>>(
            future: _rows,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: snapshot.hasError
                      ? Text(_error(snapshot.error!))
                      : const CircularProgressIndicator(),
                );
              }
              final rows = snapshot.data!;
              final attended = rows.where((r) => r.attended).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _query.isEmpty
                          ? '${rows.length} RSVPed · $attended checked in'
                          : '${rows.length} found for "$_query"',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'Nobody has RSVPed yet. Search to check in a '
                                  'walk-in, or scan their code.'
                            : 'Nobody matches. Only members who have joined '
                                  'the app can be checked in.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final row in rows)
                    ListTile(
                      key: Key('check-in-${row.id}'),
                      leading: Icon(
                        row.attended
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: row.attended ? AppColors.green : null,
                      ),
                      title: Text(row.displayName),
                      subtitle: Text(
                        [
                          if (row.attended)
                            row.checkInLine
                          else if (row.status != null)
                            'RSVP: ${row.status}'
                          else
                            'No RSVP',
                          if (row.shifts.isNotEmpty) row.shifts.join(', '),
                        ].join(' · '),
                      ),
                      trailing: row.attended
                          ? const Text('Undo')
                          : FilledButton.tonal(
                              onPressed: () => _toggle(row),
                              child: const Text('Check in'),
                            ),
                      onTap: () => _toggle(row),
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

class _ListsTab extends StatefulWidget {
  const _ListsTab({super.key, required this.event, required this.service});

  final CommunityEvent event;
  final EventsService service;

  @override
  State<_ListsTab> createState() => _ListsTabState();
}

class _ListsTabState extends State<_ListsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<EventLists> _future = widget.service.fetchLists(widget.event.id);
  String _list = 'attended';

  @override
  bool get wantKeepAlive => true;

  void reload() => setState(() {
    _future = widget.service.fetchLists(widget.event.id);
  });

  Future<void> _export(String label) async {
    try {
      final csv = await widget.service.exportList(widget.event.id, _list);
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          mimeType: 'text/csv',
          name: 'event-${widget.event.id}-$_list.csv',
        ),
      ], subject: '${widget.event.title}: $label');
    } catch (e) {
      if (mounted) _say(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async => reload(),
      child: FutureBuilder<EventLists>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(_error(snapshot.error!))
                  : const CircularProgressIndicator(),
            );
          }
          final data = snapshot.data!;
          final rows = data.lists[_list] ?? const <AttendeeRow>[];
          final label = data.labels[_list] ?? _list;
          return ListView(
            key: const Key('event-lists'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final entry in data.labels.entries)
                    ChoiceChip(
                      key: Key('list-${entry.key}'),
                      label: Text(
                        '${entry.value} ${data.counts[entry.key] ?? 0}',
                      ),
                      selected: _list == entry.key,
                      onSelected: (_) => setState(() => _list = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label (${rows.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('export-list'),
                    onPressed: rows.isEmpty ? null : () => _export(label),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Nobody on this list.'),
                ),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.displayName),
                  subtitle: Text(
                    [
                      if (row.programYear != null)
                        'Class of ${row.programYear}',
                      if (row.attended) row.checkInLine,
                      if (!row.attended && row.status != null)
                        'RSVP: ${row.status}',
                      if (row.shifts.isNotEmpty) row.shifts.join(', '),
                      if ((row.email ?? '').isNotEmpty) row.email!,
                    ].join(' · '),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The camera, reading members' check-in codes. Each scan checks the
/// member in and shows their name and photo to match at the door.
class CheckInScannerScreen extends StatefulWidget {
  const CheckInScannerScreen({
    super.key,
    required this.event,
    required this.service,
  });

  final CommunityEvent event;
  final EventsService service;

  @override
  State<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends State<CheckInScannerScreen> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);
  ScanResult? _result;
  String? _problem;
  int _count = 0;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || _busy) return;
    // The same code stays in view for a while; act on it once.
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inSeconds < 4) return;
    _lastCode = code;
    _lastAt = now;
    setState(() => _busy = true);
    try {
      final result = await widget.service.scanCheckIn(widget.event.id, code);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _result = result;
        _problem = null;
        _count = result.attendedCount;
      });
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _result = null;
        _problem = _error(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan: ${widget.event.title}'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _camera.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera access is off. Turn it on for Emerge KY Alumni '
                            'in Settings to scan check-in codes.'
                      : 'The camera could not start: ${error.errorCode.name}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _ResultCard(
              result: _result,
              problem: _problem,
              busy: _busy,
              count: _count,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.problem,
    required this.busy,
    required this.count,
  });

  final ScanResult? result;
  final String? problem;
  final bool busy;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    if (busy) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking in…'),
            ],
          ),
        ),
      );
    }
    if (problem != null) {
      return Card(
        key: const Key('scan-problem'),
        color: AppColors.alertBackground,
        child: ListTile(
          leading: const Icon(
            Icons.error_outline,
            color: AppColors.alertAccent,
          ),
          title: Text(problem!),
        ),
      );
    }
    if (r == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.qr_code_2),
          title: Text('Point the camera at a member\'s check-in code.'),
          subtitle: Text('They open it from the event or Settings.'),
        ),
      );
    }
    final photo = r.profilePic;
    return Card(
      key: const Key('scan-result'),
      color: r.alreadyCheckedIn
          ? Colors.amber.shade50
          : AppColors.green.withValues(alpha: 0.15),
      child: ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundImage: photo == null
              ? null
              : NetworkImage(
                  photo.startsWith('http') ? photo : ApiEndpoints.host + photo,
                ),
          child: photo == null ? Text(r.displayName.characters.first) : null,
        ),
        title: Text(r.displayName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          [
            r.alreadyCheckedIn ? 'Already checked in' : 'Checked in',
            if (r.walkIn) 'walk-in',
            if (r.programYear != null) 'Class of ${r.programYear}',
            '$count here',
          ].join(' · '),
        ),
        trailing: Icon(
          r.alreadyCheckedIn ? Icons.info_outline : Icons.check_circle,
          color: r.alreadyCheckedIn ? Colors.amber.shade800 : AppColors.green,
          size: 32,
        ),
      ),
    );
  }
}
