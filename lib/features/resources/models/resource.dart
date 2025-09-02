import 'package:cloud_firestore/cloud_firestore.dart';

class Resource {
  final String id;
  final String name;
  final String provider;
  final String description;
  final String url;
  final List<String> tags;
  final String category;

  Resource({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.url,
    required this.tags,
    required this.category,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] ?? '',
    );
  }
}
