import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';

class CacheDetailsController with ChangeNotifier {
  final GeocacheRepository repo;
  final String cacheId;

  StreamSubscription<Geocache?>? _sub;

  Geocache? cache;
  bool loading = true;
  bool working = false;
  String? error;

  CacheDetailsController({required this.repo, required this.cacheId});

  void start() {
    _sub?.cancel();

    loading = true;
    error = null;
    notifyListeners();

    _sub = repo.watchCacheById(cacheId).listen(
      (c) {
        cache = c;
        loading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> setPinLocation(GeoPoint location) async {
    final current = cache;
    if (current == null) return;

    working = true;
    error = null;
    notifyListeners();

    try {
      final updated = Geocache(
        id: current.id,
        title: current.title,
        descriptionMd: current.descriptionMd,
        status: current.status,
        location: location,
        passwordHash: current.passwordHash,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      await repo.updateCache(updated);
    } catch (e) {
      error = e.toString();
    } finally {
      working = false;
      notifyListeners();
    }
  }

  Future<void> toggleHidden() async {
    final current = cache;
    if (current == null) return;

    working = true;
    error = null;
    notifyListeners();

    try {
      final nextStatus = current.status == CacheStatus.active ? CacheStatus.hidden : CacheStatus.active;
      final updated = Geocache(
        id: current.id,
        title: current.title,
        descriptionMd: current.descriptionMd,
        status: nextStatus,
        location: current.location,
        passwordHash: current.passwordHash,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      await repo.updateCache(updated);
    } catch (e) {
      error = e.toString();
    } finally {
      working = false;
      notifyListeners();
    }
  }

  Future<void> delete() async {
    working = true;
    error = null;
    notifyListeners();

    try {
      await repo.deleteCache(cacheId);
    } catch (e) {
      error = e.toString();
    } finally {
      working = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
