import 'package:transconnect/core/constants/api_endpoints.dart';

class Group {
  final int id;
  final String name;
  final String? image;

  Group({required this.id, required this.name, this.image});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      image: (json['image_url'] ?? json['image'] ?? json['group_image'] ?? json['avatarUrl'] ?? json['avatar_url']) as String?,
    );
  }

  String? get fullImageUrl {
    if (image == null) return null;
    if (image!.startsWith('http')) return image;
    if (image!.startsWith('/')) return '${ApiEndpoints.host}${image!}';
    return '${ApiEndpoints.host}/media/${image!}';
  }
}
