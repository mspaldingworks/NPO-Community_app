class GeocacheMedia {
  final String id;
  final String cacheId;
  final String? url;
  final String? localPath;
  final String caption;
  final DateTime createdAt;

  const GeocacheMedia({
    required this.id,
    required this.cacheId,
    required this.url,
    required this.localPath,
    required this.caption,
    required this.createdAt,
  });

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'cache_id': cacheId,
      'url': url,
      'local_path': localPath,
      'caption': caption,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static GeocacheMedia fromDbMap(Map<String, Object?> row) {
    return GeocacheMedia(
      id: row['id'] as String,
      cacheId: row['cache_id'] as String,
      url: row['url'] as String?,
      localPath: row['local_path'] as String?,
      caption: row['caption'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
