import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/group.dart';

class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  late final CommunityService _communityService;
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _groupsFuture = _communityService.fetchGroups();
  }

  Group? _findByNames(List<Group> groups, List<String> names) {
    for (final g in groups) {
      final n = g.name.trim().toLowerCase();
      for (final name in names) {
        if (n == name.toLowerCase()) return g;
      }
    }
    for (final g in groups) {
      final n = g.name.trim().toLowerCase();
      for (final name in names) {
        if (n.contains(name.toLowerCase())) return g;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Album')),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final groups = snapshot.data ?? [];

          final hugbox = _findByNames(groups, ['hugbox', 'hug box']);
          final honest = _findByNames(groups, [
            'honest improvement',
            'honest-improvement',
            'improvement',
          ]);

          final items = <_CardItem>[
            _CardItem(
              title: 'Hugbox',
              subtitle: 'Get unconditional encouragement — no critique.',
              icon: Icons.favorite,
              group: hugbox,
            ),
            _CardItem(
              title: 'Honest Improvement',
              subtitle: 'Ask for candid, constructive feedback to grow.',
              icon: Icons.thumbs_up_down,
              group: honest,
            ),
          ];

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _IconCard(
                title: item.title,
                subtitle: item.subtitle,
                iconData: item.icon,
                onTap: item.group == null
                    ? null
                    : () {
                        GoRouter.of(context).push(
                          '/community/group/${item.group!.id}',
                          extra: item.group!.name,
                        );
                      },
              );
            },
          );
        },
      ),
    );
  }
}

class _CardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Group? group;
  _CardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.group,
  });
}

class _IconCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final VoidCallback? onTap;

  const _IconCard({
    required this.title,
    required this.subtitle,
    required this.iconData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Icon(iconData, size: 64, color: color.withOpacity(0.7)),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onTap == null)
              const Positioned(
                right: 8,
                top: 8,
                child: Tooltip(
                  message: 'Coming soon or not available',
                  child: Icon(Icons.lock, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
