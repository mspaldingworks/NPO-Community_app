enum CacheLogType {
  found,
  didNotFind,
  note,
  maintenance,
}

class GeocacheLog {
  final String id;
  final String cacheId;
  final String userUsername;
  final CacheLogType type;
  final String message;
  final DateTime createdAt;

  const GeocacheLog({
    required this.id,
    required this.cacheId,
    required this.userUsername,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'cache_id': cacheId,
      'user_username': userUsername,
      'type': type.name,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static GeocacheLog fromDbMap(Map<String, Object?> row) {
    return GeocacheLog(
      id: row['id'] as String,
      cacheId: row['cache_id'] as String,
      userUsername: row['user_username'] as String,
      type: CacheLogType.values.byName(row['type'] as String),
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
