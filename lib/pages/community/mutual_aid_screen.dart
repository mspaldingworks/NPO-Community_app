import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/pages/community/activity_feed_screen.dart';

class MutualAidContent extends StatelessWidget {
  const MutualAidContent({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ActivityFeedScreen(
      showAppBar: false,
      header: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: _IconCard(
                  title: 'Request Help',
                  iconData: Icons.handshake_outlined,
                  color: color,
                  onTap: () async {
                    final result = await context.push<bool>('/forms/lgl');
                    if (result == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thanks for submitting the form!'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: _IconCard(
                  title: 'Browse Listings',
                  iconData: Icons.search,
                  color: color,
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MutualAidScreen extends StatelessWidget {
  const MutualAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutual Aid')),
      body: const MutualAidContent(),
    );
  }
}

class _IconCard extends StatelessWidget {
  final String title;
  final IconData iconData;
  final Color color;
  final VoidCallback onTap;

  const _IconCard({
    required this.title,
    required this.iconData,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  colors: [color.withAlpha(38), color.withAlpha(89)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Icon(iconData, size: 64, color: color.withAlpha(204)),
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
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
