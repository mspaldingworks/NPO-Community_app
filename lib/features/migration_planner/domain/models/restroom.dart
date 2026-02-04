class Restroom {
  final int? id;
  final String name;
  final String? directions;
  final String? comment;
  final double latitude;
  final double longitude;
  final bool? accessible;
  final bool? unisex;
  final String? updatedAt;

  const Restroom({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.directions,
    this.comment,
    this.accessible,
    this.unisex,
    this.updatedAt,
  });

  factory Restroom.fromJson(Map<String, dynamic> json) {
    return Restroom(
      id: json['id'] as int?,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Unnamed restroom',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      directions: json['directions'] as String?,
      comment: json['comment'] as String?,
      accessible: json['accessible'] as bool?,
      unisex: json['unisex'] as bool?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  String get dedupeKey {
    if (id != null) return 'id-$id';
    return 'loc-${latitude.toStringAsFixed(5)}-${longitude.toStringAsFixed(5)}';
  }
}
