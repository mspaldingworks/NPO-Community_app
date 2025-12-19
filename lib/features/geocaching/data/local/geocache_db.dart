import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class GeocacheDb {
  static final GeocacheDb _instance = GeocacheDb._internal();
  factory GeocacheDb() => _instance;
  GeocacheDb._internal();

  static const String _dbName = 'geocaching.db';
  static const int _dbVersion = 5;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _opening ??= _open();
    _db = await _opening!;
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS cache_media');
          await db.execute('DROP TABLE IF EXISTS cache_logs');
          await db.execute('DROP TABLE IF EXISTS caches');
          await _createSchema(db);
          return;
        }

        if (oldVersion < 5) {
          await _createCacheLogs(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE caches(
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description_md TEXT,
  status TEXT NOT NULL,
  lat REAL,
  lng REAL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('CREATE INDEX caches_lat_lng_idx ON caches(lat, lng);');
    await db.execute('CREATE INDEX caches_status_idx ON caches(status);');
    await db.execute('CREATE INDEX caches_updated_at_idx ON caches(updated_at);');

    await _createCacheLogs(db);
  }

  Future<void> _createCacheLogs(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS cache_logs(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cache_id TEXT NOT NULL,
  type TEXT NOT NULL,
  actor_username TEXT,
  actor_user_id INTEGER,
  created_at TEXT NOT NULL,
  metadata_json TEXT
)
''');
    await db.execute('CREATE INDEX IF NOT EXISTS cache_logs_cache_id_idx ON cache_logs(cache_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS cache_logs_created_at_idx ON cache_logs(created_at);');
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    if (db != null) {
      await db.close();
    }
  }
}
