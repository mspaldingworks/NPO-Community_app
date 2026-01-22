import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/models/group.dart';

class _Hotspot {
  final String region; // key used by idForRegion
  final double x; // left as fraction of width (0..1)
  final double y; // top as fraction of height (0..1)
  final double w; // width as fraction of width (0..1)
  final double h; // height as fraction of height (0..1)
  const _Hotspot(this.region, this.x, this.y, this.w, this.h);
}

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

          String? idForRegion(String key) {
            String k = key.trim().toLowerCase();
            Group find(bool Function(Group) test) => regionGroups.firstWhere(
                  test,
                  orElse: () => Group(id: 0, name: ''),
                );
            if (k == 'western ky') {
              final g = find((g) => g.name.toLowerCase().contains('western ky'));
              return g.id == 0 ? null : g.id.toString();
            }
            if (k == 'central ky') {
              final g = find((g) => g.name.toLowerCase().contains('central ky') || g.name.toLowerCase().contains('greater lexington'));
              return g.id == 0 ? null : g.id.toString();
            }
            if (k == 'eastern ky') {
              final g = find((g) => g.name.toLowerCase().contains('eastern ky'));
              return g.id == 0 ? null : g.id.toString();
            }
            if (k == 'south-central ky') {
              final g = find((g) => g.name.toLowerCase().contains('south-central ky') || g.name.toLowerCase().contains('south central ky'));
              return g.id == 0 ? null : g.id.toString();
            }
            if (k == 'northern ky') {
              final g = find((g) => g.name.toLowerCase().contains('northern ky') || g.name.toLowerCase().contains('northern kentucky'));
              return g.id == 0 ? null : g.id.toString();
            }
            if (k == 'louisville') {
              final g = find((g) => g.name.toLowerCase().contains('kentuckiana'));
              return g.id == 0 ? null : g.id.toString();
            }
            return null;
          }

          double zoomForRegion(String key) {
            switch (key) {
              case 'louisville':
                return 1.5;
              case 'northern ky':
                return 1.45;
              case 'central ky':
                return 1.35;
              case 'south-central ky':
                return 1.30;
              case 'eastern ky':
                return 1.30;
              case 'western ky':
                return 1.25;
            }
            return 1.25;
          }

          // Normalize a group name to our region key set
          String? regionKeyForGroupName(String name) {
            final n = name.trim().toLowerCase();
            if (n.contains('kentuckiana')) return 'louisville';
            if (n.contains('central ky') || n.contains('greater lexington')) return 'central ky';
            if (n.contains('eastern ky')) return 'eastern ky';
            if (n.contains('western ky')) return 'western ky';
            if (n.contains('south-central ky') || n.contains('south central ky')) return 'south-central ky';
            if (n.contains('northern ky') || n.contains('northern kentucky')) return 'northern ky';
            return null;
          }

          // Compute an Alignment (-1..1) for the region center, based on the hotspot rectangles above
          Alignment? alignmentForRegion(String key) {
            switch (key) {
              case 'western ky': {
                final cx = 0.02 + 0.35 / 2; // representative of the larger western block
                final cy = 0.42 + 0.40 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
              case 'louisville': {
                final cx = 0.44 + 0.17 / 2;
                final cy = 0.28 + 0.36 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
              case 'northern ky': {
                final cx = 0.62 + 0.12 / 2;
                final cy = 0.12 + 0.20 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
              case 'central ky': {
                final cx = 0.60 + 0.16 / 2;
                final cy = 0.30 + 0.33 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
              case 'eastern ky': {
                final cx = 0.76 + 0.20 / 2;
                final cy = 0.24 + 0.56 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
              case 'south-central ky': {
                final cx = 0.38 + 0.45 / 2; // use the larger bottom band
                final cy = 0.62 + 0.22 / 2;
                return Alignment((cx - 0.5) * 2, (cy - 0.5) * 2);
              }
            }
            return null;
          }

          // Try to load an asset image for the region. If not found, fall back to
          // the statewide map with alignment. Finally, fall back to gradient.
          Widget regionImageWidget({required String key, required Alignment? align}) {
            final slug = () {
              switch (key) {
                case 'western ky': return 'western_ky';
                case 'south-central ky': return 'south_central_ky';
                case 'louisville': return 'louisville_ky';
                case 'northern ky': return 'northern_ky';
                case 'eastern ky': return 'eastern_ky';
                case 'central ky': return 'central_ky';
              }
              return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
            }();

            final Alignment effectiveAlign = align ?? Alignment.center;
            final double zoom = zoomForRegion(key);

            // Prefer the explicit filenames added in pubspec.yaml, then ky_* fallbacks,
            // then a local statewide map, finally network fallback.
            final List<String> candidates = () {
              switch (key) {
                case 'western ky':
                  return [
                    'assets/media/WKY-Regions-Map-2048x1046.jpg',
                    'assets/media/ky_$slug.jpg',
                    'assets/media/ky_$slug.png',
                  ];
                case 'south-central ky':
                  return [
                    'assets/media/SouthCentralKY-Regions-Map-2048x1046.jpg',
                    'assets/media/ky_$slug.jpg',
                    'assets/media/ky_$slug.png',
                  ];
                case 'louisville':
                  return [
                    'assets/media/Regions-Map-2048x1046.jpg',
                  ];
                case 'northern ky':
                  return [
                    'assets/media/NorthernKY-Regions-Map-2048x1046.jpg',
                    'assets/media/ky_$slug.jpg',
                    'assets/media/ky_$slug.png',
                  ];
                case 'eastern ky':
                  return [
                    'assets/media/EasternKY-Regions-Map-2048x1046.jpg',
                    'assets/media/ky_$slug.jpg',
                    'assets/media/ky_$slug.png',
                  ];
                case 'central ky':
                  return [
                    'assets/media/Regions-Map-2048x1046.jpg',
                  ];
              }
              return [
                'assets/media/ky_$slug.jpg',
                'assets/media/ky_$slug.png',
              ];
            }();

            Widget networkFallback() => CachedNetworkImage(
                  imageUrl: kyMapUrl,
                  httpHeaders: null,
                  fit: BoxFit.cover,
                  alignment: effectiveAlign,
                );

            Widget localMapFallback() => Image.asset(
                  'assets/media/Regions-Map-2048x1046.jpg',
                  fit: BoxFit.cover,
                  alignment: effectiveAlign,
                  errorBuilder: (context, error, stack) => networkFallback(),
                );

            Widget tryAssetAt(int i) {
              if (i >= candidates.length) {
                return localMapFallback();
              }
              final path = candidates[i];
              return Image.asset(
                path,
                fit: BoxFit.cover,
                alignment: effectiveAlign,
                errorBuilder: (context, error, stack) => tryAssetAt(i + 1),
              );
            }

            return Transform.scale(
              scale: zoom,
              alignment: effectiveAlign,
              child: tryAssetAt(0),
            );
          }

          Widget kyMapWithHotspots() {
            final List<_Hotspot> spots = [
              _Hotspot('western ky', 0.02, 0.42, 0.35, 0.40),
              _Hotspot('western ky', 0.30, 0.42, 0.12, 0.25),
              _Hotspot('louisville', 0.44, 0.28, 0.17, 0.36),
              _Hotspot('northern ky', 0.62, 0.12, 0.12, 0.20),
              _Hotspot('central ky', 0.60, 0.30, 0.16, 0.33),
              _Hotspot('eastern ky', 0.76, 0.24, 0.20, 0.56),
              _Hotspot('south-central ky', 0.56, 0.50, 0.10, 0.09),
              _Hotspot('south-central ky', 0.38, 0.62, 0.45, 0.22),
            ];

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 2048 / 1046,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      return Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: bannerImageUrl,
                            httpHeaders: null,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          for (final s in spots)
                            if (idForRegion(s.region) != null)
                              Positioned(
                                left: w * s.x,
                                top: h * s.y,
                                width: w * s.w,
                                height: h * s.h,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      final id = idForRegion(s.region);
                                      if (id != null) {
                                        GoRouter.of(context).push('/community/group/$id', extra: s.region);
                                      }
                                    },
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: kyMapWithHotspots(),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = regionGroups[index];
                      final imgUrl = group.fullImageUrl;
                      final regionKey = regionKeyForGroupName(group.name);
                      final regionAlignment = regionKey != null ? alignmentForRegion(regionKey) : null;
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
                              else if (regionKey != null)
                                regionImageWidget(key: regionKey, align: regionAlignment)
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                        Theme.of(context).colorScheme.primary.withOpacity(0.28),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
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
