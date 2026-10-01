import 'package:flutter/material.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CampaignLinkOpener = Future<bool> Function(Uri uri);

/// Opens a public campaign link in the in-app browser, falling back to the
/// external browser.
Future<bool> openCampaignLink(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {}
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Human-readable countdown to election day.
String? electionCountdownText(AlumniCandidate candidate, DateTime now) {
  final days = candidate.daysUntilElection(now);
  if (days == null) return null;
  if (days > 1) return '$days days to go';
  if (days == 1) return 'Tomorrow';
  if (days == 0) return 'Election day!';
  return 'Election held';
}

class CandidateAvatar extends StatelessWidget {
  const CandidateAvatar({super.key, required this.candidate, this.radius = 26});

  final AlumniCandidate candidate;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headshot = candidate.headshotUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      foregroundImage: headshot == null
          ? null
          : NetworkImage(headshot.toString()),
      onForegroundImageError: headshot == null ? null : (_, _) {},
      child: Text(candidate.initials),
    );
  }
}

class CandidateStatusChip extends StatelessWidget {
  const CandidateStatusChip({super.key, required this.status});

  final CandidateRaceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (status) {
      CandidateRaceStatus.won => (
        colors.primary,
        colors.onPrimary,
        Icons.emoji_events,
      ),
      CandidateRaceStatus.wonPrimary => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        Icons.celebration_outlined,
      ),
      CandidateRaceStatus.didNotWin => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        Icons.flag_outlined,
      ),
      _ => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.how_to_vote_outlined,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(status.label),
      labelStyle: TextStyle(color: fg),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
