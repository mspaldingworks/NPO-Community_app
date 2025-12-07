import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';

class SexualHealthScreen extends StatefulWidget {
  const SexualHealthScreen({super.key});

  @override
  State<SexualHealthScreen> createState() => _SexualHealthScreenState();
}

class _SexualHealthScreenState extends State<SexualHealthScreen> {
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
      appBar: AppBar(title: const Text('Sexual Wellness')),
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
          final sexualHealth = _findByNames(groups, [
            'sexual health',
            'sexual-health',
            'sexual wellness',
            'sexual health & wellness',
            'sexual'
          ]);
          final kink = _findByNames(groups, ['kink', 'kinky', 'bdsm', 'fetish']);
          final prepPep = _findByNames(groups, ['prep', 'pep', 'hiv prevention', 'prep & pep', 'prep/pep']);
          final stiTesting = _findByNames(groups, ['sti testing', 'std testing', 'testing', 'clinics']);
          final saferSex = _findByNames(groups, ['safer sex', 'sex ed', 'sex education']);
          final consent = _findByNames(groups, ['consent', 'boundaries']);

          final items = <_CardItem>[
            _CardItem(title: 'Sexual Wellness (General)', icon: Icons.favorite, group: sexualHealth),
            _CardItem(title: 'Kink', icon: Icons.favorite_border, group: kink),
            _CardItem(title: 'PrEP & PEP Access', icon: Icons.medication, group: prepPep),
            _CardItem(title: 'STI Testing & Clinics', icon: Icons.medical_services, group: stiTesting),
            _CardItem(title: 'Safer Sex Tips', icon: Icons.health_and_safety, group: saferSex),
            _CardItem(title: 'Consent & Boundaries', icon: Icons.rule, group: consent),
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
                iconData: item.icon,
                onTap: item.group == null
                    ? null
                    : () {
                        GoRouter.of(context).push('/community/group/${item.group!.id}', extra: item.group!.name);
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
  final IconData icon;
  final Group? group;
  _CardItem({required this.title, required this.icon, this.group});
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
