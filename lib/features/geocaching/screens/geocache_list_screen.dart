import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/utils/cache_collections.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';

class GeocacheListScreen extends StatefulWidget {
  const GeocacheListScreen({super.key});

  @override
  State<GeocacheListScreen> createState() => _GeocacheListScreenState();
}

class _GeocacheListScreenState extends State<GeocacheListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, String> _unlockedHashesById = const {};
  bool _hasUnreadCollections = false;

  @override
  void initState() {
    super.initState();
    _loadUnlocked();
    _loadUnreadCollections();
  }

  Future<void> _loadUnreadCollections() async {
    final hasUnread = await CacheCollections.hasUnread();
    if (!mounted) return;
    setState(() {
      _hasUnreadCollections = hasUnread;
    });
  }

  Future<void> _loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final next = <String, String>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('cache_unlocked_hash_')) continue;
      final id = k.substring('cache_unlocked_hash_'.length);
      final v = prefs.getString(k);
      if (v != null) next[id] = v;
    }

    if (!mounted) return;
    setState(() {
      _unlockedHashesById = next;
    });
  }

  Future<void> _openCache(BuildContext context, Geocache cache) async {
    await context.push('/geocaching/cache/${cache.id}');
    await _loadUnlocked();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<GeocacheRepository>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);

    final search = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caches'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Cache Admin',
              icon: Icon(
                Icons.admin_panel_settings_outlined,
                color: _hasUnreadCollections ? Colors.pinkAccent : null,
              ),
              onPressed: () async {
                await context.push('/geocaching/admin');
                await _loadUnreadCollections();
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Geocache>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var items = snap.data ?? const <Geocache>[];

          if (!isAdmin) {
            items = items.where((c) => c.status == CacheStatus.active).toList();
          }

          if (search.isNotEmpty) {
            items = items.where((c) => c.title.toLowerCase().contains(search)).toList();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No caches found.')),
                )
              else
                ...items.map(
                  (c) {
                    final pinned = c.location != null;
                    final subtitle = pinned ? 'Pin placed' : 'No pin placed yet';

                    final unlocked = isAdmin || _unlockedHashesById[c.id] == c.passwordHash;
                    final lockLabel = isAdmin
                        ? null
                        : (unlocked ? 'Unlocked' : 'Locked');

                    return Card(
                      child: ListTile(
                        title: Text(c.title),
                        subtitle: Text(lockLabel == null ? subtitle : '$subtitle • $lockLabel'),
                        leading: Icon(
                          pinned ? Icons.location_on : Icons.location_off,
                          color: pinned ? Colors.redAccent : null,
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!isAdmin) Icon(unlocked ? Icons.lock_open : Icons.lock_outline),
                            if (isAdmin && c.status == CacheStatus.hidden) const Icon(Icons.visibility_off_outlined),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openCache(context, c),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
