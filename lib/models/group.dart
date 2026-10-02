import 'package:npo_community/core/constants/api_endpoints.dart';

class Group {
  final int id;
  final String name;
  final String? image;

  /// Seeded alumni groups: 'statewide', 'regional' or 'cohort' (one per
  /// class year); member-created groups are 'custom'.
  final String kind;
  final String? slug;
  final String? regionId;
  final int? programYear;

  Group({
    required this.id,
    required this.name,
    this.image,
    this.kind = 'custom',
    this.slug,
    this.regionId,
    this.programYear,
  });

  bool get isStatewide => kind == 'statewide';
  bool get isRegional => kind == 'regional';
  bool get isCohort => kind == 'cohort';

  factory Group.fromJson(Map<String, dynamic> json) {
    final regionId = json['region_id'];
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      kind: (json['kind'] as String?) ?? 'custom',
      slug: json['slug'] as String?,
      regionId: regionId is String && regionId.isNotEmpty ? regionId : null,
      programYear: json['program_year'] as int?,
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

/// A regional group as listed by `/api/groups/regions/`.
class RegionalGroup {
  RegionalGroup({
    required this.group,
    required this.isMember,
    required this.isHome,
  });

  final Group group;
  final bool isMember;

  /// The region the member's county belongs to.
  final bool isHome;

  factory RegionalGroup.fromJson(Map<String, dynamic> json) => RegionalGroup(
    group: Group.fromJson(json),
    isMember: json['is_member'] == true,
    isHome: json['is_home'] == true,
  );
}
