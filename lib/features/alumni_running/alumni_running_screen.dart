import 'package:flutter/material.dart';
import 'package:npo_community/features/alumni_running/alumni_candidates.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CampaignLinkOpener = Future<bool> Function(Uri uri);

Future<bool> _defaultOpenLink(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {}
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Highlights Emerge Kentucky alumni running for office this year, with a
/// card per candidate that opens their live campaign page.
class AlumniRunningScreen extends StatelessWidget {
  const AlumniRunningScreen({super.key, this.candidates, this.openLink});

  /// Optional injected list (used in tests). Defaults to the curated list.
  final List<AlumniCandidate>? candidates;

  /// Optional injected link opener (used in tests).
  final CampaignLinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    final list = candidates ?? alumniCandidates2026;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alumni on the Ballot')),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No alumni candidates are listed yet. Check back soon.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'Emerge Kentucky alumni running in 2026. Tap a card to '
                    'visit their campaign and show your support.',
                    style: textTheme.bodyMedium,
                  );
                }
                return AlumniCandidateCard(
                  candidate: list[index - 1],
                  openLink: openLink ?? _defaultOpenLink,
                );
              },
            ),
    );
  }
}

class AlumniCandidateCard extends StatelessWidget {
  const AlumniCandidateCard({
    super.key,
    required this.candidate,
    required this.openLink,
  });

  final AlumniCandidate candidate;
  final CampaignLinkOpener openLink;

  Future<void> _open(BuildContext context) async {
    final uri = candidate.primaryUrl;
    if (uri == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await openLink(uri);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open ${uri.host}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final uri = candidate.primaryUrl;
    final linkLabel = candidate.hasCampaignPage
        ? 'Visit campaign page'
        : 'View candidate info';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: uri == null ? null : () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(candidate.initials),
                  ),
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
                        Text(
                          candidate.office,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      candidate.election,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (uri != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _open(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(linkLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
