import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:transconnect/features/geocaching/data/local/geocache_db.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/utils/cache_password.dart';

class LocalGeocacheRepository implements GeocacheRepository {
  final GeocacheDb _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Distance _distance = const Distance();

  Future<void>? _seedFuture;

  LocalGeocacheRepository({GeocacheDb? db}) : _db = db ?? GeocacheDb();

  Future<void> _ensureSeeded() {
    _seedFuture ??= _seedIfEmpty();
    return _seedFuture!;
  }

  Future<void> _seedIfEmpty() async {
    final db = await _db.database;
    final existing = await db.query('caches', columns: const ['id'], limit: 1);
    if (existing.isNotEmpty) return;

    try {
      final raw = await rootBundle.loadString('lib/data/pins.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final batch = db.batch();
      for (final item in decoded) {
        if (item is! Map) continue;

        final id = (item['id'] as String?)?.trim();
        final title = (item['title'] as String?)?.trim();
        final lat = item['lat'];
        final lng = item['lng'];

        if (id == null || id.isEmpty) continue;
        if (title == null || title.isEmpty) continue;

        final GeoPoint? location = (lat is num && lng is num)
            ? GeoPoint(lat: lat.toDouble(), lng: lng.toDouble())
            : null;

        final rawPassword = (item['password'] as String?)?.trim();
        final password = (rawPassword != null && rawPassword.isNotEmpty) ? rawPassword : '${id}_pass';
        final passwordHash = hashCachePassword(cacheId: id, password: password);

        final statusName = (item['status'] as String?)?.trim() ?? CacheStatus.active.name;
        final status = CacheStatus.values.contains(CacheStatus.hidden) && statusName == CacheStatus.hidden.name
            ? CacheStatus.hidden
            : CacheStatus.active;

        final createdAtRaw = item['createdAt'] as String?;
        final updatedAtRaw = item['updatedAt'] as String?;
        final createdAt = createdAtRaw != null ? DateTime.parse(createdAtRaw).toLocal() : DateTime.now();
        final updatedAt = updatedAtRaw != null ? DateTime.parse(updatedAtRaw).toLocal() : createdAt;

        final cache = Geocache(
          id: id,
          title: title,
          descriptionMd: item['descriptionMd'] as String?,
          status: status,
          location: location,
          passwordHash: passwordHash,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        batch.insert(
          'caches',
          cache.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await batch.commit(noResult: true);
      _emitChange();
    } catch (_) {
      // If seeding fails (missing asset, bad JSON), keep app functional.
    }
  }

  void _emitChange() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<List<Geocache>> watchAll() async* {
    yield await getAllOnce();
    await for (final _ in _changes.stream) {
      yield await getAllOnce();
    }
  }

  @override
  Future<List<Geocache>> getAllOnce() async {
    await _ensureSeeded();
    final db = await _db.database;
    final rows = await db.query('caches', orderBy: 'updated_at DESC');
    return rows.map(Geocache.fromDbMap).toList();
  }

  @override
  Stream<List<Geocache>> watchNearby(GeocacheQuery query) async* {
    yield await getNearbyOnce(query);
    await for (final _ in _changes.stream) {
      yield await getNearbyOnce(query);
    }
  }

  @override
  Future<List<Geocache>> getNearbyOnce(GeocacheQuery query) async {
    await _ensureSeeded();
    final db = await _db.database;

    final centerLat = query.center.lat;
    final centerLng = query.center.lng;

    const metersPerDegreeLat = 111320.0;
    final degLat = query.radiusMeters / metersPerDegreeLat;
    final cosLat = cos(centerLat * pi / 180.0).abs();
    final metersPerDegreeLng = metersPerDegreeLat * (cosLat < 0.00001 ? 0.00001 : cosLat);
    final degLng = query.radiusMeters / metersPerDegreeLng;

    final minLat = centerLat - degLat;
    final maxLat = centerLat + degLat;
    final minLng = centerLng - degLng;
    final maxLng = centerLng + degLng;

    final where = <String>[
      'lat IS NOT NULL',
      'lng IS NOT NULL',
      'lat BETWEEN ? AND ?',
      'lng BETWEEN ? AND ?',
      'status = ?',
    ];

    final args = <Object?>[minLat, maxLat, minLng, maxLng, query.status.name];

    if (query.text != null && query.text!.trim().isNotEmpty) {
      where.add('title LIKE ?');
      args.add('%${query.text!.trim()}%');
    }

    final rows = await db.query(
      'caches',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );

    final center = LatLng(centerLat, centerLng);
    final results = <Geocache>[];

    for (final r in rows) {
      final cache = Geocache.fromDbMap(r);
      final loc = cache.location;
      if (loc == null) continue;
      final d = _distance.as(LengthUnit.Meter, center, loc.toLatLng());
      if (d <= query.radiusMeters) {
        results.add(cache);
      }
    }

    results.sort((a, b) {
      final al = a.location;
      final bl = b.location;
      if (al == null && bl == null) return 0;
      if (al == null) return 1;
      if (bl == null) return -1;
      final da = _distance.as(LengthUnit.Meter, center, al.toLatLng());
      final dbb = _distance.as(LengthUnit.Meter, center, bl.toLatLng());
      return da.compareTo(dbb);
    });

    return results;
  }

  @override
  Future<Geocache?> getCacheById(String id) async {
    await _ensureSeeded();
    final db = await _db.database;
    final rows = await db.query('caches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Geocache.fromDbMap(rows.first);
  }

  @override
  Stream<Geocache?> watchCacheById(String id) async* {
    yield await getCacheById(id);
    await for (final _ in _changes.stream) {
      yield await getCacheById(id);
    }
  }

  @override
  Future<Geocache> createCache(Geocache draft) async {
    final db = await _db.database;

    await db.insert(
      'caches',
      draft.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _emitChange();
    return draft;
  }

  @override
  Future<Geocache> updateCache(Geocache cache) async {
    final db = await _db.database;

    await db.insert(
      'caches',
      cache.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _emitChange();
    return cache;
  }

  @override
  Future<void> deleteCache(String id) async {
    final db = await _db.database;
    await db.delete('caches', where: 'id = ?', whereArgs: [id]);
    _emitChange();
  }

  void dispose() {
    _changes.close();
  }
}
