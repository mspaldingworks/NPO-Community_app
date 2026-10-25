import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/features/class_fundraising/class_fundraising_service.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// One bar from $0 to the goal. Past the goal the bar stays full and says so.
class FundraisingBar extends StatelessWidget {
  const FundraisingBar({
    super.key,
    required this.raisedCents,
    required this.goalCents,
    this.height = 10,
  });

  final int raisedCents;
  final int goalCents;
  final double height;

  @override
  Widget build(BuildContext context) {
    final met = goalCents > 0 && raisedCents >= goalCents;
    final fraction = goalCents <= 0
        ? 0.0
        : (raisedCents / goalCents).clamp(0.0, 1.0);
    final color = met ? AppColors.green : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label:
              '${formatDollars(raisedCents)} of ${formatDollars(goalCents)} raised',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: height,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${formatDollars(raisedCents)} of ${formatDollars(goalCents)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (met) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 14, color: AppColors.green),
              const SizedBox(width: 2),
              Text('Goal met', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ],
    );
  }
}

class _PreviewNote extends StatelessWidget {
  const _PreviewNote();

  @override
  Widget build(BuildContext context) => const Card(
    key: Key('class-fundraising-preview'),
    color: AppColors.alertBackground,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sample amounts. Givebutter isn\'t connected yet, so these '
              'bars show made-up figures, not real donations.',
            ),
          ),
        ],
      ),
    ),
  );
}

/// The newest class's fundraising: the class total, then one bar per member
/// from $0 to their goal (the viewer's own first). The Class of <year>
/// group's Fundraising tab and the /class-fundraising screen.
class ClassFundraisingList extends StatefulWidget {
  const ClassFundraisingList({super.key, this.service});

  /// Injected in tests.
  final ClassFundraisingService? service;

  @override
  State<ClassFundraisingList> createState() => _ClassFundraisingListState();
}

class _ClassFundraisingListState extends State<ClassFundraisingList> {
  late final ClassFundraisingService _service =
      widget.service ?? ClassFundraisingService();
  late Future<ClassFundraising> _future = _service.fetch();

  Future<void> _reload() async {
    final future = _service.fetch();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<ClassFundraising>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      Center(
                        child: TextButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            key: const Key('class-fundraising-list'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (data.isPreview) const _PreviewNote(),
              Text(
                'Class of ${data.year}: each member is raising '
                '${formatDollars(data.goalCents)} for Emerge Kentucky.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (!data.available)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Givebutter totals are unavailable right now. Pull down '
                    'to try again.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Text('Class total', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                FundraisingBar(
                  key: const Key('class-total-bar'),
                  raisedCents: data.totalRaisedCents,
                  goalCents: data.totalGoalCents,
                  height: 14,
                ),
                const SizedBox(height: 20),
                for (final member in data.members)
                  _MemberRow(member: member, goalCents: data.goalCents),
                if (data.members.isEmpty)
                  const Text('Nobody is in this year\'s class yet.'),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.goalCents});

  final ClassFundraiser member;
  final int goalCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = Uri.tryParse(member.url);
    return Padding(
      key: Key('class-fundraiser-${member.id}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.isMe
                      ? '${member.displayName} (you)'
                      : member.displayName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (member.donors > 0)
                Text(
                  '${member.donors} ${member.donors == 1 ? 'donor' : 'donors'}',
                  style: theme.textTheme.bodySmall,
                ),
              if (page != null && page.hasScheme)
                IconButton(
                  tooltip: 'Give to ${member.displayName}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () =>
                      launchUrl(page, mode: LaunchMode.externalApplication),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FundraisingBar(raisedCents: member.raisedCents, goalCents: goalCents),
        ],
      ),
    );
  }
}

/// /class-fundraising: the list as its own screen (from Home).
class ClassFundraisingScreen extends StatelessWidget {
  const ClassFundraisingScreen({super.key, this.service});

  final ClassFundraisingService? service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class fundraising')),
    body: ClassFundraisingList(service: service),
  );
}

/// Home's card for a member of the newest class: their own bar, opening the
/// whole class's. Shows nothing if the call fails or they aren't listed.
class MyClassFundraisingCard extends StatefulWidget {
  const MyClassFundraisingCard({super.key, this.service});

  /// Injected in tests.
  final ClassFundraisingService? service;

  @override
  State<MyClassFundraisingCard> createState() => _MyClassFundraisingCardState();
}

class _MyClassFundraisingCardState extends State<MyClassFundraisingCard> {
  late final Future<ClassFundraising?> _future = _load();

  Future<ClassFundraising?> _load() async {
    try {
      return await (widget.service ?? ClassFundraisingService()).fetch();
    } catch (_) {
      return null;
    }
  }

  void _open() {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/class-fundraising');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClassFundraisingScreen(service: widget.service),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ClassFundraising?>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final me = data?.me;
      if (data == null || me == null || !data.available) {
        return const SizedBox.shrink();
      }
      return Card(
        key: const Key('home-class-fundraising'),
        child: InkWell(
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your fundraising goal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (data.isPreview)
                      Text(
                        'Sample',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                FundraisingBar(
                  raisedCents: me.raisedCents,
                  goalCents: data.goalCents,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
