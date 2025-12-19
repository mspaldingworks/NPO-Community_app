import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/utils/cache_password.dart';

class PlaceCacheController with ChangeNotifier {
  final GeocacheRepository repo;
  final GeoPoint? location;
  final Geocache? existing;

  String title;
  String descriptionMd;
  CacheStatus status;
  String password;
  String confirmPassword;

  bool saving = false;
  String? error;

  PlaceCacheController({
    required this.repo,
    required this.location,
    this.existing,
  })  : title = existing?.title ?? '',
        descriptionMd = existing?.descriptionMd ?? '',
        status = existing?.status ?? CacheStatus.active,
        password = '',
        confirmPassword = '';

  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';

    final editing = existing != null;
    final p = password.trim();
    final cp = confirmPassword.trim();

    if (!editing) {
      if (p.isEmpty) return 'Password is required.';
      if (p != cp) return 'Passwords do not match.';
    } else {
      if (p.isNotEmpty || cp.isNotEmpty) {
        if (p != cp) return 'Passwords do not match.';
      }
    }
    return null;
  }

  Future<Geocache?> save() async {
    error = validate();
    if (error != null) {
      notifyListeners();
      return null;
    }

    saving = true;
    notifyListeners();

    try {
      final now = DateTime.now();

      final candidatePassword = password.trim();
      if (candidatePassword.isNotEmpty) {
        final caches = await repo.getAllOnce();
        final currentId = existing?.id;
        final conflict = caches.any(
          (c) => c.id != currentId &&
              verifyCachePassword(
                cacheId: c.id,
                password: candidatePassword,
                passwordHash: c.passwordHash,
              ),
        );
        if (conflict) {
          error = 'That password is already used by another cache.';
          return null;
        }
      }

      final current = existing;
      if (current == null) {
        final loc = location;
        if (loc == null) {
          error = 'Pin location is required.';
          return null;
        }

        final id = const Uuid().v4();
        final passwordHash = hashCachePassword(cacheId: id, password: password);

        final cache = Geocache(
          id: id,
          title: title.trim(),
          descriptionMd: descriptionMd.trim().isEmpty ? null : descriptionMd.trim(),
          status: status,
          location: loc,
          passwordHash: passwordHash,
          createdAt: now,
          updatedAt: now,
        );

        final created = await repo.createCache(cache);
        return created;
      }

      final nextPasswordHash = password.trim().isEmpty
          ? current.passwordHash
          : hashCachePassword(cacheId: current.id, password: password);

      final updated = Geocache(
        id: current.id,
        title: title.trim(),
        descriptionMd: descriptionMd.trim().isEmpty ? null : descriptionMd.trim(),
        status: status,
        location: current.location,
        passwordHash: nextPasswordHash,
        createdAt: current.createdAt,
        updatedAt: now,
      );

      return await repo.updateCache(updated);
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
