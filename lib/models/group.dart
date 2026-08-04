import 'package:npo_community/core/constants/api_endpoints.dart';

class Group {
  final int id;
  final String name;
  final String? image;

  Group({required this.id, required this.name, this.image});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      image:
          (json['image_url'] ??
                  json['image'] ??
                  json['group_image'] ??
                  json['avatarUrl'] ??
                  json['avatar_url'])
              as String?,
    );
  }

  String? get fullImageUrl {
    final raw = image;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lowered = trimmed.toLowerCase();
    if (lowered == 'null' || lowered == 'none') return null;
    if (trimmed.startsWith('http')) return trimmed;
    if (trimmed.startsWith('/')) return '${ApiEndpoints.host}$trimmed';
    return '${ApiEndpoints.host}/media/$trimmed';
  }
}
