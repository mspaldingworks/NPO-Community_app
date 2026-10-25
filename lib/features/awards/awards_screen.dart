import 'package:flutter/material.dart';
import 'package:npo_community/features/awards/award_widgets.dart';
import 'package:npo_community/features/awards/awards_service.dart';

/// The awards gallery: a grid of square artwork, one tab for alumni awards
/// and one for the current class's achievements. Awards both share appear
/// in both. Each tile opens the award's page with how to earn it. The tab
/// for the member's own set opens first.
class AwardsScreen extends StatefulWidget {
  const AwardsScreen({
    super.key,
    this.service,
    this.inCurrentClass = false,
    this.now,
  });

  /// Injected in tests.
  final AwardsService? service;

  /// Whether the viewer is in the newest class (their tab opens first).
  final bool inCurrentClass;

  /// Clock override for tests (names the class year).
  final DateTime Function()? now;

  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  late final AwardsService _service = widget.service ?? AwardsService();
  late Future<AwardCatalog> _future = _service.fetchCatalog();

  Future<void> _reload() async {
    final future = _service.fetchCatalog();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final year = (widget.now ?? DateTime.now)().year;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.inCurrentClass ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Awards & achievements'),
          bottom: TabBar(
            tabs: [
              const Tab(key: Key('tab-alumni-awards'), text: 'Alumni awards'),
              Tab(
                key: const Key('tab-class-achievements'),
                text: 'Class of $year',
              ),
            ],
          ),
        ),
        body: FutureBuilder<AwardCatalog>(
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
            final catalog = snapshot.data!;
            return TabBarView(
              children: [
                _Gallery(
                  key: const Key('gallery-alumni'),
                  catalog: catalog,
                  awards: [
                    for (final a in catalog.awards)
                      if (!a.isClassAchievement) a,
                  ],
                  intro:
                      'Alumni awards: for showing up, backing alumnae on the '
                      'ballot and welcoming the newest class.',
                  onRefresh: _reload,
                ),
                _Gallery(
                  key: const Key('gallery-class'),
                  catalog: catalog,
                  awards: [
                    for (final a in catalog.awards)
                      if (!a.isAlumniAward) a,
                  ],
                  intro:
                      'Class of $year achievements: for getting to know your '
                      'class, building your network and reaching your '
                      'fundraising goal.',
                  onRefresh: _reload,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One set as a grid of artwork: earned first, then the rest in catalog
/// order, each tile showing progress when there is some.
class _Gallery extends StatelessWidget {
  const _Gallery({
    super.key,
    required this.catalog,
    required this.awards,
    required this.intro,
    required this.onRefresh,
  });

  final AwardCatalog catalog;
  final List<Award> awards;
  final String intro;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grantsByAward = <int, List<AwardGrant>>{};
    for (final grant in catalog.mine) {
      grantsByAward.putIfAbsent(grant.award.id, () => []).add(grant);
    }
    final earned = [
      for (final a in awards)
        if (a.earned > 0) a,
    ];
    final rest = [
      for (final a in awards)
        if (a.earned == 0) a,
    ];
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 5 : (width >= 600 ? 4 : 3);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${earned.length} of ${awards.length} earned',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: earned.length + rest.length,
              itemBuilder: (context, index) {
                final award = index < earned.length
                    ? earned[index]
                    : rest[index - earned.length];
                return _Tile(
                  award: award,
                  grants: grantsByAward[award.id] ?? const [],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.award, required this.grants});

  final Award award;
  final List<AwardGrant> grants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final held = award.earned > 0;
    final progress = award.progress;
    return InkWell(
      key: Key('gallery-${award.key}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => showAwardDetails(context, award, grants: grants),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AwardArt(award: award, locked: !held, count: award.earned),
          const SizedBox(height: 6),
          Text(
            award.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!held && progress != null && progress.value > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 4,
                color: award.colorValue,
                backgroundColor: award.colorValue.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
