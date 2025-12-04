import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/models/group.dart';

class RegionalChatsScreen extends StatefulWidget {
  const RegionalChatsScreen({super.key});

  @override
  State<RegionalChatsScreen> createState() => _RegionalChatsScreenState();
}

class _RegionalChatsScreenState extends State<RegionalChatsScreen> {
  late final CommunityService _communityService;
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _groupsFuture = _communityService.fetchGroups();
  }

  bool _isRegion(Group g) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regional Chats')),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final regionGroups = (snapshot.data ?? []).where(_isRegion).toList();
          final token = SharedPreferencesService().getData('user_token');
          final headers = token != null ? {'Authorization': 'Token $token'} : null;

          const String kyMapUrl = 'https://louisvilleyouthgroup.org/wp-content/uploads/2025/12/Regions-Map-2048x1046-1.jpg';
          final String bannerImageUrl = kyMapUrl;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: InkWell(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: bannerImageUrl,
                              httpHeaders: null,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              height: 180,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black54],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              bottom: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Regional Map',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = regionGroups[index];
                      final imgUrl = group.fullImageUrl;
                      return InkWell(
                        onTap: () => GoRouter.of(context).push('/community/group/${group.id}', extra: group.name),
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
                                Container(color: Theme.of(context).colorScheme.surfaceVariant),
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
                    childCount: regionGroups.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
