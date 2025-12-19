import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';

class Geocache {
  final String id;
  final String title;
  final String? descriptionMd;
  final CacheStatus status;
  final GeoPoint? location;
  final String passwordHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Geocache({
    required this.id,
    required this.title,
    required this.descriptionMd,
    required this.status,
    required this.location,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description_md': descriptionMd,
      'status': status.name,
      'lat': location?.lat,
      'lng': location?.lng,
      'password_hash': passwordHash,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static Geocache fromDbMap(Map<String, Object?> row) {
    final lat = row['lat'];
    final lng = row['lng'];

    return Geocache(
      id: row['id'] as String,
      title: row['title'] as String,
      descriptionMd: row['description_md'] as String?,
      status: CacheStatus.values.byName(row['status'] as String),
      location: (lat is num && lng is num)
          ? GeoPoint(
              lat: lat.toDouble(),
              lng: lng.toDouble(),
            )
          : null,
      passwordHash: row['password_hash'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
