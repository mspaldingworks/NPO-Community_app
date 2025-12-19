import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:transconnect/features/geocaching/controllers/cache_details_controller.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/utils/cache_password.dart';
import 'package:transconnect/features/geocaching/utils/cache_collections.dart';
import 'package:transconnect/features/geocaching/models/cache_log_event.dart';
import 'package:transconnect/features/geocaching/utils/cache_logs.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';

class CacheDetailsScreen extends StatefulWidget {
  final String cacheId;

  const CacheDetailsScreen({super.key, required this.cacheId});

  @override
  State<CacheDetailsScreen> createState() => _CacheDetailsScreenState();
}

class _CacheDetailsScreenState extends State<CacheDetailsScreen> {
  CacheDetailsController? _ctrl;

  final MapController _mapController = MapController();
  GeoPoint? _lastCentered;

  bool _unlocked = false;
  bool _checkingUnlock = false;

  bool _checkingCollected = false;
  bool _collectedByMe = false;
  String? _collectedCheckedKey;

  String? _unlockCheckedKey;

  Future<List<CacheLogEvent>>? _logFuture;
  String? _logCacheId;

  static const GeoPoint _kentuckyCenter = GeoPoint(lat: 37.8393, lng: -84.2700);

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/geocaching');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl != null) return;

    final repo = Provider.of<GeocacheRepository>(context, listen: false);
    _ctrl = CacheDetailsController(repo: repo, cacheId: widget.cacheId)..start();
  }

  Future<void> _refreshCollectedState({required String cacheId, required String username}) async {
    setState(() {
      _checkingCollected = true;
    });

    try {
      final events = await CacheCollections.getEvents();
      final collected = events.any((e) => e.cacheId == cacheId && e.collectedByUsername == username);
      if (!mounted) return;
      setState(() {
        _collectedByMe = collected;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingCollected = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  static String _unlockKey(String id) => 'cache_unlocked_hash_$id';

  static String _formatWhen(DateTime when) {
    return '${when.month}/${when.day}/${when.year} ${when.hour.toString().padLeft(2, "0")}:${when.minute.toString().padLeft(2, "0")}';
  }

  Future<List<CacheLogEvent>> _getAdminLogEvents(String cacheId) async {
    final dbEvents = await CacheLogs.getEventsForCache(cacheId);

    final collections = await CacheCollections.getEvents();
    final claimed = collections
        .where((e) => e.cacheId == cacheId)
        .map(
          (e) => CacheLogEvent(
            id: null,
            cacheId: cacheId,
            type: 'claimed',
            actorUsername: e.collectedByUsername,
            actorUserId: e.collectedByUserId,
            createdAt: e.collectedAt,
            metadata: <String, Object?>{
              'cacheTitle': e.cacheTitle,
            },
          ),
        )
        .toList();

    final merged = <CacheLogEvent>[
      ...dbEvents.where((e) => e.type != 'claimed'),
      ...claimed,
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  void _ensureLogFuture(String cacheId) {
    if (_logCacheId == cacheId && _logFuture != null) return;
    _logCacheId = cacheId;
    _logFuture = _getAdminLogEvents(cacheId);
  }

  void _reloadLog(String cacheId) {
    setState(() {
      _logCacheId = cacheId;
      _logFuture = _getAdminLogEvents(cacheId);
    });
  }

  Future<void> _refreshUnlockState({required String cacheId, required String passwordHash}) async {
    setState(() {
      _checkingUnlock = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_unlockKey(cacheId));
      if (!mounted) return;
      setState(() {
        _unlocked = storedHash == passwordHash;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingUnlock = false;
      });
    }
  }

  Future<bool> _attemptUnlock({
    required String cacheId,
    required String passwordHash,
    required String password,
    required String actorUsername,
    required int? actorUserId,
  }) async {
    setState(() {
      _checkingUnlock = true;
    });

    try {
      final ok = verifyCachePassword(
        cacheId: cacheId,
        password: password,
        passwordHash: passwordHash,
      );
      if (!ok) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unlockKey(cacheId), passwordHash);

      try {
        await CacheLogs.addEvent(
          CacheLogEvent(
            id: null,
            cacheId: cacheId,
            type: 'unlocked',
            actorUsername: actorUsername,
            actorUserId: actorUserId,
            createdAt: DateTime.now(),
            metadata: const <String, Object?>{},
          ),
        );
      } catch (_) {
      }

      if (!mounted) return false;
      setState(() {
        _unlocked = true;
      });
      return true;
    } finally {
      if (!mounted) return false;
      setState(() {
        _checkingUnlock = false;
      });
    }
  }

  Future<void> _showUnlockDialog({
    required String cacheId,
    required String passwordHash,
    required String title,
    required String actorUsername,
    required int? actorUserId,
  }) async {
    final ctrl = TextEditingController();
    bool working = false;
    String? error;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Unlock $title'),
              content: TextField(
                controller: ctrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
                onSubmitted: working
                    ? null
                    : (_) async {
                        setState(() {
                          working = true;
                          error = null;
                        });
                        final ok = await _attemptUnlock(
                          cacheId: cacheId,
                          passwordHash: passwordHash,
                          password: ctrl.text,
                          actorUsername: actorUsername,
                          actorUserId: actorUserId,
                        );
                        if (!mounted) return;
                        if (!ok) {
                          setState(() {
                            working = false;
                            error = 'Incorrect password.';
                          });
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop(true);
                      },
              ),
              actions: [
                TextButton(
                  onPressed: working ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: working
                      ? null
                      : () async {
                          setState(() {
                            working = true;
                            error = null;
                          });
                          final ok = await _attemptUnlock(
                            cacheId: cacheId,
                            passwordHash: passwordHash,
                            password: ctrl.text,
                            actorUsername: actorUsername,
                            actorUserId: actorUserId,
                          );
                          if (!mounted) return;
                          if (!ok) {
                            setState(() {
                              working = false;
                              error = 'Incorrect password.';
                            });
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        },
                  child: working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);
    final ctrl = _ctrl;

    if (ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        if (ctrl.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (ctrl.error != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Cache'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
              automaticallyImplyLeading: false,
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ctrl.error!),
            ),
          );
        }

        final cache = ctrl.cache;
        if (cache == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Cache'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
              automaticallyImplyLeading: false,
            ),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cache not found.'),
            ),
          );
        }

        if (!isAdmin) {
          final key = '${cache.id}:${cache.passwordHash}';
          if (_unlockCheckedKey != key) {
            _unlockCheckedKey = key;
            _unlocked = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _refreshUnlockState(cacheId: cache.id, passwordHash: cache.passwordHash);
            });
          }
        }

        final me = auth.currentUser;
        final username = me?.username ?? 'Unknown';
        if ((isAdmin || _unlocked) && _collectedCheckedKey != '${cache.id}:$username') {
          _collectedCheckedKey = '${cache.id}:$username';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _refreshCollectedState(cacheId: cache.id, username: username);
          });
        }

        final loc = cache.location;
        if (loc != null && (_lastCentered == null || _lastCentered!.lat != loc.lat || _lastCentered!.lng != loc.lng)) {
          _lastCentered = loc;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(loc.toLatLng(), 15.0);
          });
        }

        final statusText = cache.status == CacheStatus.active ? 'Active' : 'Hidden';

        return Scaffold(
          appBar: AppBar(
            title: Text(cache.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBack,
            ),
            automaticallyImplyLeading: false,
            actions: [
              if (!isAdmin)
                IconButton(
                  tooltip: _unlocked ? 'Unlocked' : 'Unlock',
                  icon: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline),
                  onPressed: _checkingUnlock
                      ? null
                      : () => _showUnlockDialog(
                            cacheId: cache.id,
                            passwordHash: cache.passwordHash,
                            title: cache.title,
                            actorUsername: username,
                            actorUserId: me?.id,
                          ),
                ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/geocaching/edit/${cache.id}'),
                ),
              if (isAdmin)
                IconButton(
                  tooltip: cache.status == CacheStatus.active ? 'Hide' : 'Unhide',
                  icon: Icon(cache.status == CacheStatus.active ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: ctrl.working ? null : ctrl.toggleHidden,
                ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: ctrl.working
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete pin?'),
                                content: const Text('This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (ok != true) return;

                          await ctrl.delete();
                          if (!context.mounted) return;
                          context.pop();
                        },
                ),
            ],
          ),
          body: (!isAdmin && !_unlocked)
              ? (_checkingUnlock
                  ? const Center(child: CircularProgressIndicator())
                  : const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Locked. Tap the lock icon above to enter the password.'),
                    ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (ctrl.working)
                      const LinearProgressIndicator(minHeight: 2),

                    if (isAdmin || _unlocked) ...[
                      FilledButton.icon(
                        onPressed: (_checkingCollected || _collectedByMe)
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final added = await CacheCollections.addCollection(
                                  cache: cache,
                                  user: me,
                                  markUnread: !isAdmin,
                                );

                                if (!mounted) return;
                                if (added) {
                                  setState(() {
                                    _collectedByMe = true;
                                  });
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(added ? 'Cache claimed!' : 'You already claimed this cache.'),
                                  ),
                                );

                                if (isAdmin) {
                                  _reloadLog(cache.id);
                                }
                              },
                        icon: Icon(_collectedByMe ? Icons.check_circle_outline : Icons.flag_outlined),
                        label: Text(_collectedByMe ? 'Claimed' : 'Claim'),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      height: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: (loc ?? _kentuckyCenter).toLatLng(),
                                initialZoom: loc != null ? 15.0 : 7.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.transconnectky',
                                ),
                                if (loc != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 44,
                                        height: 44,
                                        point: LatLng(loc.lat, loc.lng),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.redAccent,
                                          size: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                      Positioned(
                        right: 12,
                        top: 12,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in_${cache.id}',
                              onPressed: () {
                                final c = _mapController.camera;
                                _mapController.move(c.center, c.zoom + 1.0);
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out_${cache.id}',
                              onPressed: () {
                                final c = _mapController.camera;
                                _mapController.move(c.center, c.zoom - 1.0);
                              },
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(statusText, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (loc != null)
                Text(
                  'Coords: ${loc.lat.toStringAsFixed(6)}, ${loc.lng.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Text(
                  'No pin placed yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              if (cache.descriptionMd != null && cache.descriptionMd!.trim().isNotEmpty)
                MarkdownBody(data: cache.descriptionMd!)
              else
                const Text('No description.'),

              if (isAdmin) ...[
                const SizedBox(height: 16),
                _buildAdminLog(cacheId: cache.id),
              ],

              if (ctrl.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  ctrl.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminLog({required String cacheId}) {
    _ensureLogFuture(cacheId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Admin log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _reloadLog(cacheId),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            FutureBuilder<List<CacheLogEvent>>(
              future: _logFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                final events = snap.data ?? const <CacheLogEvent>[];
                if (events.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No log entries yet.'),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    String hashPreview(String v) {
                      final s = v.trim();
                      if (s.length <= 8) return s;
                      return '${s.substring(0, 8)}…';
                    }

                    final e = events[index];
                    final actor = (e.actorUsername == null || e.actorUsername!.trim().isEmpty) ? 'Unknown' : e.actorUsername!;
                    final when = _formatWhen(e.createdAt);

                    String title = e.type;
                    if (e.type == 'password_changed') title = 'Password changed';
                    if (e.type == 'unlocked') title = 'Unlocked';
                    if (e.type == 'claimed') title = 'Claimed';

                    final meta = e.metadata;
                    String? subtitle;
                    if (e.type == 'password_changed' && meta != null) {
                      final oldHash = meta['oldHash'];
                      final newHash = meta['newHash'];
                      if (oldHash is String && newHash is String) {
                        subtitle = 'old: ${hashPreview(oldHash)}  new: ${hashPreview(newHash)}';
                      }
                    }

                    return ListTile(
                      dense: true,
                      title: Text('$title • $actor'),
                      subtitle: Text(subtitle == null ? when : '$when\n$subtitle'),
                      isThreeLine: subtitle != null,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
