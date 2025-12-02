import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';

class RegionalChatsScreen extends StatefulWidget {
  const RegionalChatsScreen({super.key});

  @override
  State<RegionalChatsScreen> createState() => _RegionalChatsScreenState();
}

class _RegionalChatsScreenState extends State<RegionalChatsScreen> {
  late final CommunityService _communityService;
  late Future<List<Group>> _regionalGroupsFuture;

  bool _isRegionGroup(Group g) {
    final n = g.name.trim().toLowerCase();
    bool has(String s) => n.contains(s);
    final isCentral = (has('central') && (has('ky') || has('kentucky')))
        || has('central ky')
        || has('central kentucky');
    final isSouthCentral = has('south-central ky') || has('south central ky') || (has('south') && has('central') && (has('ky') || has('kentucky')));
    final isNorthern = has('northern ky') || has('northern kentucky') || has('norther ky');
    final isLexington = has('lexington');
    final isWestern = has('western ky') || (has('western') && (has('ky') || has('kentucky')));
    final isEastern = has('eastern ky') || (has('eastern') && (has('ky') || has('kentucky')));
    final isKentuckiana = has('kentuckiana') || has('louisville');
    return isKentuckiana || isLexington || isCentral || isEastern || isWestern || isSouthCentral || isNorthern;
  }

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _regionalGroupsFuture = _loadRegionalGroups();
  }

  Future<List<Group>> _loadRegionalGroups() async {
    final groups = await _communityService.fetchGroups();
    return groups.where(_isRegionGroup).toList();
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  Group? _findGroupFor(List<Group> groups, List<String> keys, {List<String> excludes = const []}) {
    for (final g in groups) {
      final gn = _norm(g.name);
      // Skip this group entirely if any exclude token appears in the name
      bool skip = false;
      for (final ex in excludes) {
        if (gn.contains(_norm(ex))) {
          // e.g., exclude 'south central' when matching 'central'
          skip = true;
          break;
        }
      }
      if (skip) continue;
      for (final k in keys) {
        if (gn.contains(_norm(k))) return g;
      }
    }
    return null;
  }

  Widget _buildRegionalMap(List<Group> groups) {
    const mapUrl = 'https://louisvilleyouthgroup.org/wp-content/uploads/2025/12/Regions-Map-2048x1046-1.jpg';
    final spots = <_RegionSpot>[
      // 1) Western KY - large left
      _RegionSpot(
        key: 'western',
        rect: const Rect.fromLTWH(0.02, 0.62, 0.34, 0.33),
        matchers: const ['western ky', 'western kentucky', 'western region', 'western'],
      ),
      // 2) Small adjunct near western edge
      _RegionSpot(
        key: 'western',
        rect: const Rect.fromLTWH(0.36, 0.52, 0.07, 0.16),
        matchers: const ['western ky', 'western kentucky', 'western'],
      ),
      // 3) Louisville / Southern Indiana (Kentuckiana) - main vertical block
      _RegionSpot(
        key: 'kentuckiana',
        rect: const Rect.fromLTWH(0.43, 0.40, 0.10, 0.40),
        matchers: const ['kentuckiana', 'louisville', 'southern indiana', 'kentuckiana regional', 'greater louisville'],
      ),
      // 4) South Central small inset near Louisville block
      _RegionSpot(
        key: 'south_central',
        rect: const Rect.fromLTWH(0.53, 0.53, 0.06, 0.12),
        matchers: const ['south central ky', 'south-central ky', 'south central', 'southcentral'],
      ),
      // 5) Kentuckiana small top cap
      _RegionSpot(
        key: 'kentuckiana',
        rect: const Rect.fromLTWH(0.50, 0.32, 0.08, 0.12),
        matchers: const ['kentuckiana', 'louisville', 'kentuckiana regional'],
      ),
      // 6) Northern KY - green rectangle top center-right
      _RegionSpot(
        key: 'northern',
        rect: const Rect.fromLTWH(0.62, 0.18, 0.19, 0.16),
        matchers: const ['northern ky', 'northern kentucky', 'northern'],
      ),
      // 7) Central KY - dark blue center block
      _RegionSpot(
        key: 'central',
        rect: const Rect.fromLTWH(0.58, 0.37, 0.21, 0.36),
        matchers: const [
          'central ky', 'central kentucky', 'central region',
          'central ky region', 'central kentucky region', 'central ky group', 'central kentucky group',
          'lexington', 'greater lexington'
        ],
        excludes: const ['south central', 'south-central', 'southcentral'],
      ),
      // 8) Eastern KY main tall block on far right
      _RegionSpot(
        key: 'eastern',
        rect: const Rect.fromLTWH(0.83, 0.34, 0.11, 0.50),
        matchers: const ['eastern ky', 'eastern kentucky', 'eastern'],
      ),
      // 9) Eastern KY small far-right adjunct
      _RegionSpot(
        key: 'eastern',
        rect: const Rect.fromLTWH(0.95, 0.46, 0.05, 0.20),
        matchers: const ['eastern ky', 'eastern kentucky', 'eastern'],
      ),
      // 10) South Central KY - large bottom center bar
      _RegionSpot(
        key: 'south_central',
        rect: const Rect.fromLTWH(0.36, 0.66, 0.47, 0.25),
        matchers: const ['south central ky', 'south-central ky', 'south central', 'southcentral'],
      ),
    ];

    return AspectRatio(
      aspectRatio: 2048 / 1046,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(mapUrl, fit: BoxFit.cover),
              for (final s in spots)
                Positioned(
                  left: s.rect.left * w,
                  top: s.rect.top * h,
                  width: s.rect.width * w,
                  height: s.rect.height * h,
                  child: Material(
                    color: Colors.transparent,
                    child: (s.rotation == 0.0)
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final g = _findGroupFor(groups, s.matchers, excludes: s.excludes);
                              if (g != null) {
                                GoRouter.of(context).push('/community/group/${g.id}', extra: g.name);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Region chat not found.')),
                                );
                              }
                            },
                            child: const SizedBox.expand(),
                          )
                        : RotatedBox(
                            quarterTurns: ((s.rotation / (math.pi / 2)).round()) % 4,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final g = _findGroupFor(groups, s.matchers, excludes: s.excludes);
                                if (g != null) {
                                  GoRouter.of(context).push('/community/group/${g.id}', extra: g.name);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Region chat not found.')),
                                  );
                                }
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Chats'),
      ),
      body: FutureBuilder<List<Group>>(
        future: _regionalGroupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final groups = snapshot.data ?? const <Group>[];
          if (groups.isEmpty) {
            return const Center(child: Text('No regional groups found.'));
          }
          return ListView.builder(
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildRegionalMap(groups),
                );
              }
              final group = groups[index - 1];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: DisplayProfilePic(imageUrl: group.fullImageUrl, radius: 20),
                  title: Text(group.name),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    GoRouter.of(context).push('/community/group/${group.id}', extra: group.name);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RegionSpot {
  final String key;
  final Rect rect;
  final List<String> matchers;
  final double rotation;
  final List<String> excludes;
  const _RegionSpot({
    required this.key,
    required this.rect,
    required this.matchers,
    this.rotation = 0.0,
    this.excludes = const [],
  });
}
