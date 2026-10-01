import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';

/// Celebratory Home card for alumni who won a primary or an election.
/// Renders nothing when there are no wins.
class AlumniWinsCard extends StatefulWidget {
  const AlumniWinsCard({super.key});

  @override
  State<AlumniWinsCard> createState() => _AlumniWinsCardState();
}

class _AlumniWinsCardState extends State<AlumniWinsCard> {
  @override
  void initState() {
    super.initState();
    final hub = context.read<CampaignHubController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => hub.ensureLoaded());
  }

  void _congratulate(AlumniCandidate candidate) {
    final post = candidate.winPost;
    context.push(post?.route ?? '/alumni/running/${candidate.id}');
  }

  @override
  Widget build(BuildContext context) {
    final wins = context.watch<CampaignHubController>().wins;
    if (wins.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const Key('alumni-wins-card'),
      color: colors.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: colors.onTertiaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Alumni wins',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final c in wins)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.name,
                  style: TextStyle(color: colors.onTertiaryContainer),
                ),
                subtitle: Text(
                  '${c.status.label} · ${c.office}',
                  style: TextStyle(color: colors.onTertiaryContainer),
                ),
                trailing: TextButton(
                  onPressed: () => _congratulate(c),
                  child: const Text('Congratulate'),
                ),
                onTap: () => context.push('/alumni/running/${c.id}'),
              ),
          ],
        ),
      ),
    );
  }
}
