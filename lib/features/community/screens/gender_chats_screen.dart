import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';

class GenderChatsScreen extends StatefulWidget {
  const GenderChatsScreen({super.key});

  @override
  State<GenderChatsScreen> createState() => _GenderChatsScreenState();
}

class GeneralChatsScreen extends StatefulWidget {
  const GeneralChatsScreen({super.key});

  @override
  State<GeneralChatsScreen> createState() => _GeneralChatsScreenState();
}

class _GeneralChatsScreenState extends State<GeneralChatsScreen> {
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
      appBar: AppBar(title: const Text('General')),
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
          final generalGroup = _findByNames(groups, ['general']);
          final hobbiesGroup = _findByNames(groups, ['hobbies', 'hobby']);
          final items = <_CardItem>[
            _CardItem(title: 'General Chat', icon: Icons.forum, group: generalGroup),
            _CardItem(title: 'Hobbies', icon: Icons.interests, group: hobbiesGroup),
          ];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 140,
                  child: _IconCard(
                    title: item.title,
                    iconData: item.icon,
                    onTap: () {
                      if (item.group != null) {
                        GoRouter.of(context).push('/community/group/${item.group!.id}', extra: item.group!.name);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GenderChatsScreenState extends State<GenderChatsScreen> {
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
    // fallback: contains match
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
      appBar: AppBar(title: const Text('Gender Identity Chats')),
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

          final items = <_CardItem>[
            _CardItem(
              title: 'Trans Femmes',
              icon: Icons.female,
              group: _findByNames(groups, ['trans femmes', 'trans femme', 'femmes']),
            ),
            _CardItem(
              title: 'Trans Mascs',
              icon: Icons.male,
              group: _findByNames(groups, ['trans mascs', 'trans masc', 'mascs']),
            ),
            _CardItem(
              title: 'Nonbinary / Gender-Expansive',
              icon: Icons.transgender,
              group: _findByNames(groups, ['nonbinary', 'non-binary', 'gender-expansive', 'nonbinary/ gender-expansive']),
            ),
            _CardItem(
              title: 'Partners / Families',
              icon: Icons.family_restroom,
              group: _findByNames(groups, ['partners/ families', 'partners & families', 'partners and families', 'families']),
            ),
            _CardItem(
              title: 'General',
              icon: Icons.forum,
              route: '/community/gender/general',
            ),
          ];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 140,
                  child: _IconCard(
                    title: item.title,
                    iconData: item.icon,
                    onTap: () {
                      if (item.route != null) {
                        GoRouter.of(context).push(item.route!);
                      } else if (item.group != null) {
                        GoRouter.of(context).push('/community/group/${item.group!.id}', extra: item.group!.name);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LegalChatsScreen extends StatefulWidget {
  const LegalChatsScreen({super.key});

  @override
  State<LegalChatsScreen> createState() => _LegalChatsScreenState();
}

class _LegalChatsScreenState extends State<LegalChatsScreen> {
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
      appBar: AppBar(title: const Text('Legal Topics')),
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
          final legalGroup = _findByNames(groups, ['legal', 'legal help', 'legal topics']);
          final items = <_CardItem>[
            _CardItem(title: 'Legal', icon: Icons.gavel, group: legalGroup),
          ];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 140,
                  child: _IconCard(
                    title: item.title,
                    iconData: item.icon,
                    onTap: () {
                      if (item.route != null) {
                        GoRouter.of(context).push(item.route!);
                      } else if (item.group != null) {
                        GoRouter.of(context).push('/community/group/${item.group!.id}', extra: item.group!.name);
                      }
                    },
                  ),
                ),
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
  final IconData icon;
  final Group? group;
  final String? route;
  _CardItem({required this.title, required this.icon, this.group, this.route});
}

class _IconCard extends StatelessWidget {
  final String title;
  final IconData iconData;
  final VoidCallback? onTap;

  const _IconCard({required this.title, required this.iconData, this.onTap});

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
