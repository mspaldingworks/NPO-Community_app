import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/utils/cache_collections.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';

class CacheAdminScreen extends StatefulWidget {
  const CacheAdminScreen({super.key});

  @override
  State<CacheAdminScreen> createState() => _CacheAdminScreenState();
}

class _CacheAdminScreenState extends State<CacheAdminScreen> {
  Future<List<CacheCollectionEvent>>? _eventsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventsFuture ??= CacheCollections.getEvents();

    final auth = Provider.of<AuthService>(context, listen: false);
    if (isGeocachingAdmin(auth.currentUser)) {
      CacheCollections.markAllRead();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _eventsFuture = CacheCollections.getEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cache Admin')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not authorized.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Admin'),
        actions: [
          IconButton(
            tooltip: 'Mark as read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await CacheCollections.markAllRead();
              await _reload();
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Clear collected caches?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  );
                },
              );
              if (ok != true) return;
              await CacheCollections.clearAll();
              await _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<CacheCollectionEvent>>(
        future: _eventsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snap.data ?? const <CacheCollectionEvent>[];
          if (events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No collected caches yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = events[index];
                final when = e.collectedAt;
                final whenText =
                    '${when.month}/${when.day}/${when.year} ${when.hour.toString().padLeft(2, "0")}:${when.minute.toString().padLeft(2, "0")}';

                return ListTile(
                  title: Text(e.cacheTitle),
                  subtitle: Text('${e.collectedByUsername} • $whenText'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
