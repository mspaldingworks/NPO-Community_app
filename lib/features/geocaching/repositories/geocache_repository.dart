import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';

abstract class GeocacheRepository {
  Stream<List<Geocache>> watchAll();

  Future<List<Geocache>> getAllOnce();

  Stream<List<Geocache>> watchNearby(GeocacheQuery query);

  Future<List<Geocache>> getNearbyOnce(GeocacheQuery query);

  Stream<Geocache?> watchCacheById(String id);

  Future<Geocache?> getCacheById(String id);

  Future<Geocache> createCache(Geocache draft);

  Future<Geocache> updateCache(Geocache cache);

  Future<void> deleteCache(String id);
}
