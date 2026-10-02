import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/core/config/app_config.dart';
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

/// The Ballot page: Emerge Kentucky alumnae on the ballot this year, one card
/// per candidate with their photo, race, campaign and Ballotpedia links, and
/// upcoming volunteer opportunities.
class AlumniRunningScreen extends StatelessWidget {
  const AlumniRunningScreen({
    super.key,
    this.candidates,
    this.openLink,
    this.showPhotos,
    this.now,
  });

  /// Optional injected list (used in tests). Defaults to the curated list.
  final List<AlumniCandidate>? candidates;

  /// Optional injected link opener (used in tests).
  final CampaignLinkOpener? openLink;

  /// Whether to load candidate photos. Defaults to off in demo builds, which
  /// must not make remote media requests.
  final bool? showPhotos;

  /// Optional clock (used in tests) for deciding which events are upcoming.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final today = (now ?? DateTime.now)();
    // The 2026 candidacies are hidden once Election Day is over.
    final electionOver = !today.isBefore(alumniCandidatesHideAfter);
    final list = electionOver
        ? const <AlumniCandidate>[]
        : candidates ?? alumniCandidates2026;
    final photos = showPhotos ?? AppConfig.current.networkEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Ballot')),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  electionOver
                      ? 'The 2026 general election is over. Thank you to '
                            'every Emerge Kentucky alumna who ran!'
                      : 'No alumni candidates are listed yet. Check back soon.',
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
                    'Emerge Kentucky alumnae on the ballot in '
                    '$alumniCandidatesElection. Visit their campaigns and '
                    'sign up to volunteer.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return AlumniCandidateCard(
                  candidate: list[index - 1],
                  openLink: openLink ?? _defaultOpenLink,
                  showPhoto: photos,
                  now: today,
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
    required this.showPhoto,
    required this.now,
  });

  final AlumniCandidate candidate;
  final CampaignLinkOpener openLink;
  final bool showPhoto;
  final DateTime now;

  Future<void> _open(BuildContext context, Uri uri) async {
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
    final upcoming = candidate.upcomingOpportunities(now);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CandidatePhoto(candidate: candidate, showPhoto: showPhoto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.office,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (candidate.classYear != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Emerge KY Class of ${candidate.classYear}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                      if (candidate.status != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          candidate.status!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (candidate.campaignUrl != null)
                  FilledButton.icon(
                    onPressed: () => _open(context, candidate.campaignUrl!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Campaign website'),
                  ),
                if (candidate.ballotpediaUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(context, candidate.ballotpediaUrl!),
                    icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                    label: const Text('Ballotpedia'),
                  ),
                if (candidate.donateUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(context, candidate.donateUrl!),
                    icon: const Icon(Icons.favorite_border, size: 18),
                    label: const Text('Donate'),
                  ),
              ],
            ),
            const Divider(height: 28),
            Text(
              'Upcoming volunteer opportunities',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  candidate.volunteerUrl == null
                      ? 'None listed yet. Check back soon.'
                      : 'No dated events listed yet. Sign up with the '
                            'campaign to hear about the next one.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final event in upcoming)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.event_outlined, color: colors.primary),
                  title: Text(event.title),
                  subtitle: Text(
                    [
                      _formatWhen(event.startsAt),
                      if (event.location != null) event.location!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, event.signupUrl),
                ),
            if (candidate.volunteerUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _open(context, candidate.volunteerUrl!),
                  icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                  label: const Text('Volunteer with the campaign'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatWhen(DateTime when) {
    final hasTime = when.hour != 0 || when.minute != 0;
    return DateFormat(
      hasTime ? 'EEE, MMM d · h:mm a' : 'EEE, MMM d',
    ).format(when);
  }
}

/// Circular headshot that falls back to initials when there is no photo,
/// photos are off (demo builds), or the image fails to load.
class _CandidatePhoto extends StatelessWidget {
  const _CandidatePhoto({required this.candidate, required this.showPhoto});

  final AlumniCandidate candidate;
  final bool showPhoto;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = CircleAvatar(
      radius: _size / 2,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      child: Text(candidate.initials),
    );
    final url = candidate.photoUrl;
    if (!showPhoto || url == null) return initials;

    return ClipOval(
      child: Image.network(
        url.toString(),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        semanticLabel: 'Photo of ${candidate.name}',
        errorBuilder: (_, _, _) => initials,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : initials,
      ),
    );
  }
}
