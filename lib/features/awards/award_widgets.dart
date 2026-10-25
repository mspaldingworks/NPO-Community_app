import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/awards/awards_screen.dart';
import 'package:npo_community/features/awards/awards_service.dart';

/// An award's icon in a ring of its color. Awards not yet earned are grey.
class AwardBadge extends StatelessWidget {
  const AwardBadge({
    super.key,
    required this.award,
    this.size = 56,
    this.locked = false,
    this.count = 1,
  });

  final Award award;
  final double size;
  final bool locked;

  /// Times held; hand-given awards can be given again.
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = locked ? Colors.grey.shade500 : award.colorValue;
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: locked ? 0.08 : 0.14),
        border: Border.all(color: color, width: size / 18),
      ),
      child: Icon(award.iconData, color: color, size: size * 0.5),
    );
    return Semantics(
      label: locked ? '${award.name}, not earned yet' : award.name,
      child: count <= 1
          ? badge
          : Badge(
              label: Text('×$count'),
              backgroundColor: award.colorValue,
              offset: const Offset(-2, 2),
              child: badge,
            ),
    );
  }
}

/// Bottom sheet with what an award is for and, for one the member holds,
/// why and when they got it.
Future<void> showAwardDetails(
  BuildContext context,
  Award award, {
  List<AwardGrant> grants = const [],
}) {
  final theme = Theme.of(context);
  final held = grants.isNotEmpty;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AwardBadge(award: award, size: 88, locked: !held),
            const SizedBox(height: 12),
            Text(
              award.name,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (award.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(award.description, textAlign: TextAlign.center),
            ],
            for (final grant in grants) ...[
              const SizedBox(height: 12),
              if (grant.citation.isNotEmpty)
                Text(
                  '“${grant.citation}”',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              Text(
                [
                  if (grant.grantedAt != null)
                    DateFormat.yMMMMd().format(grant.grantedAt!),
                  if (grant.grantedBy != null) 'from ${grant.grantedBy}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (!held && award.progress != null) ...[
              const SizedBox(height: 16),
              AwardProgressBar(award: award),
            ] else if (!held && !award.automatic) ...[
              const SizedBox(height: 12),
              Text(
                'Given by Emerge Kentucky staff.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    ),
  );
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

/// A row of the awards someone holds, each opening its details. Repeat
/// grants of one award show once with a count.
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
      height: 100,
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
                    AwardBadge(award: held.first.award, count: held.length),
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

/// Home's awards panel: the member's awards with a link to all of them, or,
/// before the first one, the award they are closest to. Shows nothing if
/// the call fails.
class MyAwardsPanel extends StatefulWidget {
  const MyAwardsPanel({super.key, this.service});

  /// Injected in tests.
  final AwardsService? service;

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
          builder: (_) => AwardsScreen(service: widget.service),
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
      if (progress == null) continue;
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
      if (catalog.mine.isEmpty) {
        final next = _closest(catalog);
        return Card(
          key: const Key('home-awards'),
          child: ListTile(
            leading: next == null
                ? const Icon(Icons.emoji_events_outlined)
                : AwardBadge(award: next, size: 40, locked: true),
            title: const Text('Earn your first award'),
            subtitle: next == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${next.name}: ${next.description}'),
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
                child: Text('Your awards', style: theme.textTheme.titleMedium),
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
