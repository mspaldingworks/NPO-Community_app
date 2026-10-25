import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/features/awards/awards_screen.dart';
import 'package:npo_community/features/awards/awards_service.dart';

const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// An award's icon in a ring of its color: the fallback when an award has
/// no artwork (or artwork can't load, or the build is offline).
class AwardBadge extends StatelessWidget {
  const AwardBadge({
    super.key,
    required this.award,
    this.size = 56,
    this.locked = false,
  });

  final Award award;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = locked ? Colors.grey.shade500 : award.colorValue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: locked ? 0.08 : 0.14),
        border: Border.all(color: color, width: size / 18),
      ),
      child: Icon(award.iconData, color: color, size: size * 0.5),
    );
  }
}

/// An award's square artwork. Awards not earned yet are shown in grey;
/// awards held more than once carry a count.
class AwardArt extends StatelessWidget {
  const AwardArt({
    super.key,
    required this.award,
    this.size,
    this.locked = false,
    this.count = 1,
    this.radius = 12,
  });

  final Award award;

  /// Side length; null fills the width it is given (gallery tiles).
  final double? size;
  final bool locked;
  final int count;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.current.networkEnabled ? award.imageUrl : null;
    Widget drawn(double side) => ColoredBox(
      color: award.colorValue.withValues(alpha: 0.12),
      child: Center(
        child: AwardBadge(award: award, size: side * 0.62),
      ),
    );

    Widget art = LayoutBuilder(
      builder: (context, constraints) {
        final side = size ?? constraints.maxWidth;
        return SizedBox.square(
          dimension: side,
          child: url == null
              ? drawn(side)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => drawn(side),
                  errorWidget: (_, _, _) => drawn(side),
                ),
        );
      },
    );
    if (locked) {
      art = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(opacity: 0.55, child: art),
      );
    }
    art = ClipRRect(borderRadius: BorderRadius.circular(radius), child: art);
    if (size != null) art = SizedBox.square(dimension: size, child: art);

    return Semantics(
      label: locked ? '${award.name}, not earned yet' : award.name,
      image: true,
      child: Stack(
        children: [
          art,
          if (locked)
            Positioned(
              right: 6,
              bottom: 6,
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: Colors.grey.shade700,
              ),
            ),
          if (count > 1)
            Positioned(
              right: 4,
              top: 4,
              child: Badge(
                label: Text('×$count'),
                backgroundColor: award.colorValue,
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens an award's page: its artwork, what it's for, how to earn it, and,
/// for one the member holds, why and when they got it.
Future<void> showAwardDetails(
  BuildContext context,
  Award award, {
  List<AwardGrant> grants = const [],
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AwardDetailScreen(award: award, grants: grants),
  ),
);

class AwardDetailScreen extends StatelessWidget {
  const AwardDetailScreen({
    super.key,
    required this.award,
    this.grants = const [],
  });

  final Award award;
  final List<AwardGrant> grants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final held = grants.isNotEmpty || award.earned > 0;
    return Scaffold(
      appBar: AppBar(title: Text(award.kindLabel)),
      body: ListView(
        key: Key('award-detail-${award.key}'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: AwardArt(award: award, size: 220, locked: !held, radius: 20),
          ),
          const SizedBox(height: 16),
          Text(
            award.name,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Center(
            child: Chip(
              avatar: Icon(
                award.isClassAchievement
                    ? Icons.school_outlined
                    : award.isAlumniAward
                    ? Icons.workspace_premium_outlined
                    : Icons.groups_outlined,
                size: 18,
              ),
              label: Text(
                award.isShared
                    ? 'For alumni and the current class'
                    : award.isClassAchievement
                    ? 'For the current class'
                    : 'For alumni',
              ),
            ),
          ),
          if (award.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              award.description,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          Text('How to earn it', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            award.howToEarn.isNotEmpty
                ? award.howToEarn
                : award.automatic
                ? 'Earned automatically.'
                : 'Given by Emerge Kentucky staff.',
            key: const Key('how-to-earn'),
            style: theme.textTheme.bodyLarge,
          ),
          if (!award.eligible) ...[
            const SizedBox(height: 8),
            Text(
              award.isClassAchievement
                  ? 'This one is for members of the current class.'
                  : 'This one is for alumni of earlier classes.',
              style: theme.textTheme.bodySmall,
            ),
          ] else if (!held && award.progress != null) ...[
            const SizedBox(height: 16),
            AwardProgressBar(award: award),
          ],
          if (held) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.check_circle, color: award.colorValue),
                const SizedBox(width: 8),
                Text(
                  award.earned > 1
                      ? 'You have earned this ${award.earned} times'
                      : 'You earned this',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ],
          for (final grant in grants) ...[
            const SizedBox(height: 12),
            if (grant.citation.isNotEmpty)
              Text(
                '“${grant.citation}”',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(
              [
                if (grant.grantedAt != null)
                  DateFormat.yMMMMd().format(grant.grantedAt!),
                if (grant.grantedBy != null) 'from ${grant.grantedBy}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// "3 of 5 events" with a bar in the award's color.
class AwardProgressBar extends StatelessWidget {
  const AwardProgressBar({super.key, required this.award});

  final Award award;

  @override
  Widget build(BuildContext context) {
    final progress = award.progress;
    if (progress == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 6,
            color: award.colorValue,
            backgroundColor: award.colorValue.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.value} of ${progress.target} ${award.unit ?? ''}'.trim(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A row of the awards someone holds, each opening its page. Repeat grants
/// of one award show once with a count.
class AwardStrip extends StatelessWidget {
  const AwardStrip({super.key, required this.grants});

  final List<AwardGrant> grants;

  @override
  Widget build(BuildContext context) {
    final byAward = <int, List<AwardGrant>>{};
    for (final grant in grants) {
      byAward.putIfAbsent(grant.award.id, () => []).add(grant);
    }
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final held in byAward.values)
            InkWell(
              key: Key('award-${held.first.award.key}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  showAwardDetails(context, held.first.award, grants: held),
              child: SizedBox(
                width: 84,
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    AwardArt(
                      award: held.first.award,
                      size: 64,
                      count: held.length,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      held.first.award.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The "Awards" block on another member's profile. Shows nothing until it
/// loads, or if they hold none or the call fails.
class MemberAwardsSection extends StatefulWidget {
  const MemberAwardsSection({super.key, required this.userId, this.service});

  final int userId;

  /// Injected in tests.
  final AwardsService? service;

  @override
  State<MemberAwardsSection> createState() => _MemberAwardsSectionState();
}

class _MemberAwardsSectionState extends State<MemberAwardsSection> {
  late Future<List<AwardGrant>> _future = _load();

  @override
  void didUpdateWidget(MemberAwardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _future = _load();
  }

  Future<List<AwardGrant>> _load() async {
    try {
      return await (widget.service ?? AwardsService()).fetchMemberAwards(
        widget.userId,
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AwardGrant>>(
    future: _future,
    builder: (context, snapshot) {
      final grants = snapshot.data ?? const [];
      if (grants.isEmpty) return const SizedBox.shrink();
      return Column(
        key: const Key('member-awards'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Awards', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          AwardStrip(grants: grants),
          const SizedBox(height: 16),
        ],
      );
    },
  );
}

/// Home's awards panel: the member's awards with a link to the gallery, or,
/// before the first one, the award they are closest to. Shows nothing if
/// the call fails.
class MyAwardsPanel extends StatefulWidget {
  const MyAwardsPanel({super.key, this.service, this.inCurrentClass = false});

  /// Injected in tests.
  final AwardsService? service;

  /// Members of the newest class see "achievements".
  final bool inCurrentClass;

  @override
  State<MyAwardsPanel> createState() => _MyAwardsPanelState();
}

class _MyAwardsPanelState extends State<MyAwardsPanel> {
  late Future<AwardCatalog?> _future = _load();

  Future<AwardCatalog?> _load() async {
    try {
      return await (widget.service ?? AwardsService()).fetchCatalog();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAll() async {
    if (GoRouter.maybeOf(context) != null) {
      await context.push('/awards');
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AwardsScreen(
            service: widget.service,
            inCurrentClass: widget.inCurrentClass,
          ),
        ),
      );
    }
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  /// The automatic award the member is furthest along toward.
  Award? _closest(AwardCatalog catalog) {
    Award? best;
    for (final award in catalog.awards) {
      final progress = award.progress;
      if (progress == null || !award.eligible) continue;
      if (best == null || progress.fraction > best.progress!.fraction) {
        best = award;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AwardCatalog?>(
    future: _future,
    builder: (context, snapshot) {
      final catalog = snapshot.data;
      if (catalog == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final noun = widget.inCurrentClass ? 'achievement' : 'award';
      if (catalog.mine.isEmpty) {
        final next = _closest(catalog);
        return Card(
          key: const Key('home-awards'),
          child: ListTile(
            leading: next == null
                ? const Icon(Icons.emoji_events_outlined)
                : AwardArt(award: next, size: 48, locked: true, radius: 8),
            title: Text('Earn your first $noun'),
            subtitle: next == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${next.name}: ${next.howToEarn}'),
                        const SizedBox(height: 4),
                        AwardProgressBar(award: next),
                      ],
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openAll,
          ),
        );
      }
      return Column(
        key: const Key('home-awards'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.inCurrentClass ? 'Your achievements' : 'Your awards',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: _openAll, child: const Text('See all')),
            ],
          ),
          AwardStrip(grants: catalog.mine),
        ],
      );
    },
  );
}
