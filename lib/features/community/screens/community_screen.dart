import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _IconCard extends StatelessWidget {
  final String title;
  final IconData iconData;
  final VoidCallback onTap;

  const _IconCard({required this.title, required this.iconData, required this.onTap});

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

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<Group>> _groupsFuture;
  late final CommunityService _communityService;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _groupsFuture = _communityService.fetchGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Groups'),
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No groups found.'));
          } else {
            final groups = snapshot.data!;
            bool isRegion(Group g) {
              final n = g.name.trim().toLowerCase();
              return n == 'kentuckiana regional'
                  || n == 'greater lexington'
                  || n == 'central ky'
                  || n == 'eastern ky'
                  || n == 'western ky'
                  || n == 'south-central ky'
                  || n == 'south central ky'
                  || n == 'northern ky'
                  || n == 'northern kentucky';
            }

            bool isGender(Group g) {
              final n = g.name.trim().toLowerCase();
              return n == 'trans femmes' || n == 'trans femme'
                  || n == 'trans mascs' || n == 'trans masc'
                  || n.contains('nonbinary') || n.contains('non-binary') || n.contains('gender-expansive')
                  || n == 'partners/ families' || n.contains('partners') && n.contains('famil');
            }

            bool isLegal(Group g) {
              final n = g.name.trim().toLowerCase();
              return n == 'legal' || n.contains('legal');
            }

            bool isHobbies(Group g) {
              final n = g.name.trim().toLowerCase();
              return n.contains('hobbies') || n.contains('hobby');
            }

            final regionGroups = groups.where(isRegion).toList();
            final otherGroups = groups.where((g) => !isRegion(g) && !isGender(g) && !isLegal(g) && !isHobbies(g)).toList();

            final token = SharedPreferencesService().getData('user_token');
            final headers = token != null ? {'Authorization': 'Token $token'} : null;

            const String kyMapUrl = 'https://louisvilleyouthgroup.org/wp-content/uploads/2025/12/Regions-Map-2048x1046-1.jpg';
            const String localKyAsset = 'assets/media/Regions-Map-2048x1046.jpg';

            return CustomScrollView(
              slivers: [
                // Full-width tappable KY image (local asset preferred), no Card wrapper
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: GestureDetector(
                      onTap: () => GoRouter.of(context).push('/community/regional'),
                      child: AspectRatio(
                        aspectRatio: 2048 / 1046,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Try local asset first; if missing, fall back to network map
                              Image.asset(
                                localKyAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => CachedNetworkImage(
                                  imageUrl: kyMapUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat by region',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Divider(),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Text(
                      'All other groups',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final navCards = [
                          {'title': 'Gender Identity', 'icon': Icons.transgender, 'route': '/community/gender'},
                          {'title': 'Legal', 'icon': Icons.gavel, 'route': '/community/legal'},
                          {'title': 'Mutual Aid', 'icon': Icons.handshake_outlined, 'route': '/community/mutual-aid'},
                        ];
                        if (index < navCards.length) {
                          final item = navCards[index];
                          return _IconCard(
                            title: item['title'] as String,
                            iconData: item['icon'] as IconData,
                            onTap: () => GoRouter.of(context).push(item['route'] as String),
                          );
                        }
                        final group = otherGroups[index - navCards.length];
                        final imgUrl = group.fullImageUrl;
                        return InkWell(
                          onTap: () {
                            GoRouter.of(context).push('/community/group/${group.id}', extra: group.name);
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (imgUrl != null)
                                  CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    httpHeaders: headers,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                          Theme.of(context).colorScheme.primary.withOpacity(0.35),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                if (imgUrl == null)
                                  Center(
                                    child: Icon(
                                      Icons.groups,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    ),
                                  ),
                                Container(
                                  alignment: Alignment.bottomLeft,
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Colors.black54],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  child: Text(
                                    group.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: 3 + otherGroups.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _RegionalHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _RegionalHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

 
