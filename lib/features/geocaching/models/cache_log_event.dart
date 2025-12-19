import 'dart:convert';

class CacheLogEvent {
  final int? id;
  final String cacheId;
  final String type;
  final String? actorUsername;
  final int? actorUserId;
  final DateTime createdAt;
  final Map<String, Object?>? metadata;

  const CacheLogEvent({
    required this.id,
    required this.cacheId,
    required this.type,
    required this.actorUsername,
    required this.actorUserId,
    required this.createdAt,
    required this.metadata,
  });

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'cache_id': cacheId,
      'type': type,
      'actor_username': actorUsername,
      'actor_user_id': actorUserId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'metadata_json': metadata == null ? null : jsonEncode(metadata),
    };
  }

  static CacheLogEvent fromDbMap(Map<String, Object?> row) {
    final raw = row['metadata_json'];
    Map<String, Object?>? metadata;

    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        metadata = Map<String, Object?>.from(decoded);
      }
    }

    return CacheLogEvent(
      id: row['id'] as int?,
      cacheId: row['cache_id'] as String,
      type: row['type'] as String,
      actorUsername: row['actor_username'] as String?,
      actorUserId: row['actor_user_id'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      metadata: metadata,
    );
  }
}
