import 'package:sqflite/sqflite.dart';

import 'package:transconnect/features/geocaching/data/local/geocache_db.dart';
import 'package:transconnect/features/geocaching/models/cache_log_event.dart';

class CacheLogs {
  static Future<void> addEvent(CacheLogEvent event) async {
    final db = await GeocacheDb().database;
    await db.insert(
      'cache_logs',
      event.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  static Future<List<CacheLogEvent>> getEventsForCache(String cacheId) async {
    final db = await GeocacheDb().database;
    final rows = await db.query(
      'cache_logs',
      where: 'cache_id = ?',
      whereArgs: [cacheId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(CacheLogEvent.fromDbMap).toList();
  }
}
