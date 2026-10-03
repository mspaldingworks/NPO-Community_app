import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/group.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
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

  IconData _iconForGroup(Group group) {
    if (group.isStatewide) return Icons.flag_outlined;
    return Icons.groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
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
            // Regional and class groups have their own lists; everything
            // else (the statewide group, any custom groups) tiles here.
            final otherGroups = snapshot.data!
                .where((g) => !g.isRegional && !g.isCohort)
                .toList();

            final token = SharedPreferencesService().getData('user_token');
            final headers = token != null
                ? {'Authorization': 'Token $token'}
                : null;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: ListTile(
                      leading: const Icon(Icons.hub_outlined),
                      title: const Text('Regional groups'),
                      subtitle: const Text(
                        'Your region, plus any others you join.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          GoRouter.of(context).push('/community/regional'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('Class chats'),
                      subtitle: const Text('Your Emerge Kentucky class.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          GoRouter.of(context).push('/community/classes'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Groups',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final group = otherGroups[index];
                      final imgUrl = group.fullImageUrl;
                      return InkWell(
                        onTap: () {
                          GoRouter.of(context).push(
                            '/community/group/${group.id}',
                            extra: group.name,
                          );
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
                                        Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.15),
                                        Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.35),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              if (imgUrl == null)
                                Center(
                                  child: Icon(
                                    _iconForGroup(group),
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black54,
                                      ],
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
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: otherGroups.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
