import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/controllers/place_cache_controller.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/models/cache_log_event.dart';
import 'package:transconnect/features/geocaching/utils/cache_logs.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';

class PlaceCacheScreen extends StatefulWidget {
  final GeoPoint? location;
  final String? cacheId;

  const PlaceCacheScreen({super.key, this.location, this.cacheId});

  @override
  State<PlaceCacheScreen> createState() => _PlaceCacheScreenState();
}

class _PlaceCacheScreenState extends State<PlaceCacheScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  PlaceCacheController? _ctrl;
  Future<Geocache?>? _existingFuture;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ctrl != null || _existingFuture != null) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser;

    if (!isGeocachingAdmin(me)) {
      return;
    }

    final repo = Provider.of<GeocacheRepository>(context, listen: false);

    final cacheId = widget.cacheId;
    if (cacheId != null) {
      _existingFuture = repo.getCacheById(cacheId);
    } else {
      final loc = widget.location;
      if (loc == null) return;
      _ctrl = PlaceCacheController(repo: repo, location: loc);
      _titleCtrl.text = _ctrl!.title;
      _descCtrl.text = _ctrl!.descriptionMd;
      _passwordCtrl.text = '';
      _confirmPasswordCtrl.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);
    final me = auth.currentUser;
    final actorUsername = me?.username ?? 'Unknown';
    final actorUserId = me?.id;

    final ctrl = _ctrl;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cache')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not authorized.'),
        ),
      );
    }

    final repo = Provider.of<GeocacheRepository>(context, listen: false);
    if (widget.cacheId != null) {
      final future = _existingFuture;
      if (future == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return FutureBuilder<Geocache?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final existing = snap.data;
          if (existing == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit cache')),
              body: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Cache not found.'),
              ),
            );
          }

          if (_ctrl == null) {
            _ctrl = PlaceCacheController(repo: repo, location: existing.location, existing: existing);
            _titleCtrl.text = _ctrl!.title;
            _descCtrl.text = _ctrl!.descriptionMd;
            _passwordCtrl.text = '';
            _confirmPasswordCtrl.text = '';
          }

          return _buildForm(
            context,
            _ctrl!,
            title: 'Edit cache',
            actorUsername: actorUsername,
            actorUserId: actorUserId,
          );
        },
      );
    }

    if (ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _buildForm(
      context,
      ctrl,
      title: 'Add cache',
      actorUsername: actorUsername,
      actorUserId: actorUserId,
    );
  }

  Widget _buildForm(
    BuildContext context,
    PlaceCacheController ctrl, {
    required String title,
    required String actorUsername,
    required int? actorUserId,
  }) {
    final location = ctrl.existing?.location ?? widget.location;
    final editing = ctrl.existing != null;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (location != null)
                Text('Coordinates: ${location.lat.toStringAsFixed(6)}, ${location.lng.toStringAsFixed(6)}')
              else
                const Text('No pin placed yet.'),
              const SizedBox(height: 12),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => ctrl.title = v,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<CacheStatus>(
                value: ctrl.status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: CacheStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: ctrl.saving
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => ctrl.status = v);
                      },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Markdown)',
                  border: OutlineInputBorder(),
                ),
                minLines: 4,
                maxLines: 10,
                onChanged: (v) => ctrl.descriptionMd = v,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: editing ? 'New password (leave blank to keep current)' : 'Password',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => ctrl.password = v,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: editing ? 'Confirm new password' : 'Confirm password',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => ctrl.confirmPassword = v,
              ),
              const SizedBox(height: 16),

              if (ctrl.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  ctrl.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: ctrl.saving
                    ? null
                    : () async {
                        final existing = ctrl.existing;
                        final oldHash = existing?.passwordHash;

                        ctrl.title = _titleCtrl.text;
                        ctrl.descriptionMd = _descCtrl.text;
                        ctrl.password = _passwordCtrl.text;
                        ctrl.confirmPassword = _confirmPasswordCtrl.text;

                        final created = await ctrl.save();
                        if (!mounted) return;
                        if (created == null) return;

                        final newHash = created.passwordHash;
                        final passwordChanged = existing != null && ctrl.password.trim().isNotEmpty && oldHash != newHash;

                        if (passwordChanged && oldHash != null) {
                          try {
                            await CacheLogs.addEvent(
                              CacheLogEvent(
                                id: null,
                                cacheId: created.id,
                                type: 'password_changed',
                                actorUsername: actorUsername,
                                actorUserId: actorUserId,
                                createdAt: DateTime.now(),
                                metadata: <String, Object?>{
                                  'oldHash': oldHash,
                                  'newHash': newHash,
                                },
                              ),
                            );
                          } catch (_) {
                          }
                        }

                        if (!context.mounted) return;

                        final editing = ctrl.existing != null;
                        context.pop();
                        if (!editing) {
                          context.push('/geocaching/cache/${created.id}');
                        }
                      },
                child: ctrl.saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
