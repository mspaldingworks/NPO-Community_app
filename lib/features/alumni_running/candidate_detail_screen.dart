import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/features/alumni_running/widgets/campaign_widgets.dart';

/// A candidate's Campaign Support Hub page: how to help, volunteer shifts,
/// and the opt-in supporter channel.
class CandidateDetailScreen extends StatefulWidget {
  const CandidateDetailScreen({
    super.key,
    required this.candidateId,
    this.openLink = openCampaignLink,
    this.now,
  });

  final String candidateId;
  final CampaignLinkOpener openLink;

  /// Clock override for tests.
  final DateTime? now;

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen> {
  @override
  void initState() {
    super.initState();
    final hub = context.read<CampaignHubController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await hub.ensureLoaded();
      if (hub.candidateById(widget.candidateId) != null) {
        await hub.loadShifts(widget.candidateId);
      }
    });
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await widget.openLink(uri)) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open ${uri.host}')),
      );
    }
  }

  void _showResult(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    final candidate = hub.candidateById(widget.candidateId);

    if (candidate == null) {
      final loading =
          hub.status == CampaignHubStatus.idle ||
          hub.status == CampaignHubStatus.loading;
      return Scaffold(
        appBar: AppBar(title: const Text('Candidate')),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Text(hub.error ?? 'This candidate is no longer listed.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final now = widget.now ?? DateTime.now();
    final countdown = electionCountdownText(candidate, now);
    final date = candidate.electionDate;
    final joined = hub.isJoined(candidate.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(candidate.name),
        actions: [
          if (hub.capabilities.canManageCandidates)
            IconButton(
              key: const Key('edit-candidate'),
              tooltip: 'Edit candidate',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(
                '/alumni/running/${Uri.encodeComponent(candidate.id)}/edit',
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => hub.loadShifts(candidate.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CandidateAvatar(candidate: candidate, radius: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(candidate.office, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 6),
                      CandidateStatusChip(status: candidate.status),
                    ],
                  ),
                ),
              ],
            ),
            if (date != null || candidate.electionName != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (candidate.electionName != null)
                          candidate.electionName!,
                        if (date != null) DateFormat.yMMMMd().format(date),
                      ].join(' · '),
                    ),
                  ),
                  if (countdown != null)
                    Text(
                      countdown,
                      key: const Key('election-countdown'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
            if (candidate.bio != null) ...[
              const SizedBox(height: 16),
              Text(candidate.bio!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            _ActionButtons(candidate: candidate, onOpen: _open),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                key: const Key('message-campaign-team'),
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Message the campaign team'),
                subtitle: Text(
                  joined
                      ? "You're in the alumni supporter channel."
                      : 'Opt-in alumni supporter channel.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/alumni/running/${candidate.id}/channel'),
              ),
            ),
            if (candidate.vanId != null)
              Card(
                child: ListTile(
                  key: const Key('directory-profile-link'),
                  leading: const Icon(Icons.people_outline),
                  title: const Text('View in Alumni Directory'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    Uri(
                      path: '/directory',
                      queryParameters: {'search': candidate.name},
                    ).toString(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _ShiftsSection(candidate: candidate, onResult: _showResult),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.candidate, required this.onOpen});

  final AlumniCandidate candidate;
  final Future<void> Function(Uri) onOpen;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (candidate.campaignUrl != null)
        FilledButton.icon(
          key: const Key('action-campaign'),
          onPressed: () => onOpen(candidate.campaignUrl!),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Visit campaign'),
        ),
      if (candidate.donateUrl != null)
        FilledButton.tonalIcon(
          key: const Key('action-donate'),
          onPressed: () => onOpen(candidate.donateUrl!),
          icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
          label: const Text('Donate'),
        ),
      if (candidate.volunteerUrl != null)
        FilledButton.tonalIcon(
          key: const Key('action-volunteer'),
          onPressed: () => onOpen(candidate.volunteerUrl!),
          icon: const Icon(Icons.handshake_outlined, size: 18),
          label: const Text('Volunteer'),
        ),
      if (candidate.infoUrl != null)
        OutlinedButton.icon(
          key: const Key('action-info'),
          onPressed: () => onOpen(candidate.infoUrl!),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Candidate info'),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _ShiftsSection extends StatelessWidget {
  const _ShiftsSection({required this.candidate, required this.onResult});

  final AlumniCandidate candidate;
  final void Function(String?) onResult;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    final theme = Theme.of(context);
    final shifts = hub.shiftsFor(candidate.id);
    final error = hub.shiftErrorFor(candidate.id);
    final caps = hub.capabilities;

    final Widget body;
    if (shifts == null && error == null) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null && shifts == null) {
      body = Text(error);
    } else if (shifts!.isEmpty) {
      body = const Text('No volunteer shifts posted yet.');
    } else {
      body = Column(
        children: [
          for (final shift in shifts)
            _ShiftTile(
              shift: shift,
              enabled: caps.canSignUpForShifts,
              busy: hub.isBusy('shift:${shift.id}'),
              onSignUp: () async => onResult(await hub.signUp(shift)),
              onCancel: () async => onResult(await hub.cancel(shift)),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volunteer shifts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your sign-ups are private and appear only on your Events calendar.',
          style: theme.textTheme.bodySmall,
        ),
        if (caps.reason != null) ...[
          const SizedBox(height: 4),
          Text(caps.reason!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.shift,
    required this.enabled,
    required this.busy,
    required this.onSignUp,
    required this.onCancel,
  });

  final CampaignShift shift;
  final bool enabled;
  final bool busy;
  final VoidCallback onSignUp;
  final VoidCallback onCancel;

  IconData get _icon => switch (shift.kind) {
    CampaignShiftKind.canvass => Icons.directions_walk,
    CampaignShiftKind.phoneBank => Icons.phone_in_talk_outlined,
    CampaignShiftKind.event => Icons.groups_outlined,
    CampaignShiftKind.other => Icons.volunteer_activism_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('EEE, MMM d · h:mm a').format(shift.startsAt);
    final spots = shift.remaining == null
        ? 'Open spots'
        : shift.capacity == null
        ? '${shift.remaining} spots left'
        : '${shift.remaining} of ${shift.capacity} spots left';

    final Widget action;
    if (shift.signedUp) {
      action = OutlinedButton(
        key: Key('cancel-shift-${shift.id}'),
        onPressed: enabled && !busy ? onCancel : null,
        child: const Text('Cancel'),
      );
    } else {
      action = FilledButton(
        key: Key('signup-shift-${shift.id}'),
        onPressed: enabled && !busy && !shift.isFull ? onSignUp : null,
        child: Text(shift.isFull ? 'Full' : 'Sign up'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Icon(_icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.displayTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(when),
                  if (shift.location != null) Text(shift.location!),
                  Text(spots, key: Key('shift-spots-${shift.id}')),
                  if (shift.signedUp)
                    const Text(
                      "You're signed up",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}
