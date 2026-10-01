import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/widgets/campaign_widgets.dart';

/// "Alumni on the Ballot": Emerge Kentucky alumni running for office, with
/// a Wins section, each card opening the candidate's hub page.
class AlumniRunningScreen extends StatefulWidget {
  const AlumniRunningScreen({super.key});

  @override
  State<AlumniRunningScreen> createState() => _AlumniRunningScreenState();
}

class _AlumniRunningScreenState extends State<AlumniRunningScreen> {
  @override
  void initState() {
    super.initState();
    final hub = context.read<CampaignHubController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => hub.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alumni on the Ballot')),
      body: switch (hub.status) {
        CampaignHubStatus.idle || CampaignHubStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        CampaignHubStatus.error => _Message(
          text: hub.error ?? 'Unable to load alumni candidates.',
          onRetry: hub.load,
        ),
        CampaignHubStatus.loaded => _buildList(context, hub),
      },
    );
  }

  Widget _buildList(BuildContext context, CampaignHubController hub) {
    final candidates = hub.candidates;
    if (candidates.isEmpty) {
      return const _Message(
        text: 'No alumni candidates are listed yet. Check back soon.',
      );
    }
    final wins = hub.wins;
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: hub.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Emerge Kentucky alumni on the ballot. Open a card to see how '
            'to help, volunteer, and connect with other supporters.',
            style: textTheme.bodyMedium,
          ),
          if (wins.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Wins 🎉',
              key: const Key('wins-section'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final c in wins) ...[
              AlumniCandidateCard(candidate: c),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            'On the ballot',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final c in candidates.where((c) => !c.status.isWin)) ...[
            AlumniCandidateCard(candidate: c),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class AlumniCandidateCard extends StatelessWidget {
  const AlumniCandidateCard({super.key, required this.candidate});

  final AlumniCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countdown = electionCountdownText(candidate, DateTime.now());
    final electionLine = [
      if (candidate.electionName != null) candidate.electionName!,
      if (countdown != null) countdown,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/alumni/running/${candidate.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CandidateAvatar(candidate: candidate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(candidate.office, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    CandidateStatusChip(status: candidate.status),
                    if (electionLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(electionLine, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
