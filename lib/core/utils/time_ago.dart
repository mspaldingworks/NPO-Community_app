import 'package:intl/intl.dart';

/// Returns a concise, social-style relative time.
/// Examples: now, 5m, 2h, 3d, 2w, Mar 4, Mar 4, 2023
String timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 5) return 'now';
  if (diff.inMinutes < 1) return '1m';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';

  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w';

  // Older than ~1 month: show calendar style
  final sameYear = now.year == dateTime.year;
  final fmt = sameYear ? DateFormat('MMM d') : DateFormat('MMM d, y');
  return fmt.format(dateTime);
}
