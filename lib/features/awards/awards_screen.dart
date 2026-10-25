import 'package:flutter/material.dart';
import 'package:npo_community/features/awards/award_widgets.dart';
import 'package:npo_community/features/awards/awards_service.dart';

/// My awards: what I've earned, then every award I can still earn, by
/// category, with how close I am to the automatic ones.
class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key, this.service});

  /// Injected in tests.
  final AwardsService? service;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Awards')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<AwardCatalog>(
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
            return _AwardsList(catalog: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _AwardsList extends StatelessWidget {
  const _AwardsList({required this.catalog});

  final AwardCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toEarn = <String, List<Award>>{};
    final labels = <String, String>{};
    for (final award in catalog.awards) {
      // Hand-given awards stay listed after earning: they can come again.
      if (award.earned > 0 && award.automatic) continue;
      toEarn.putIfAbsent(award.category, () => []).add(award);
      labels[award.category] = award.categoryLabel;
    }
    final earnedCount = {for (final g in catalog.mine) g.award.id}.length;

    return ListView(
      key: const Key('awards-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          earnedCount == 0
              ? 'Show up, back alumnae on the ballot and welcome the newest '
                    'class to earn awards. They appear on your profile.'
              : 'You have earned $earnedCount '
                    '${earnedCount == 1 ? 'award' : 'awards'}. They appear on '
                    'your profile for other members to see.',
          style: theme.textTheme.bodyMedium,
        ),
        if (catalog.mine.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Earned', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AwardStrip(grants: catalog.mine),
        ],
        for (final entry in toEarn.entries) ...[
          const SizedBox(height: 20),
          Text(labels[entry.key] ?? '', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final award in entry.value) _AwardTile(award: award),
        ],
      ],
    );
  }
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({required this.award});

  final Award award;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('award-tile-${award.key}'),
      contentPadding: EdgeInsets.zero,
      leading: AwardBadge(award: award, size: 44, locked: award.earned == 0),
      title: Text(award.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (award.description.isNotEmpty) Text(award.description),
          if (award.progress != null) ...[
            const SizedBox(height: 6),
            AwardProgressBar(award: award),
          ] else if (!award.automatic)
            Text(
              award.earned > 0
                  ? 'Given to you ${award.earned == 1 ? 'once' : '${award.earned} times'}'
                  : 'Given by Emerge Kentucky staff',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () => showAwardDetails(context, award),
    );
  }
}
