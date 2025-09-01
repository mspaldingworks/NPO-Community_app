class Resource {
  final String id;
  final String name;
  final String description;
  final String? website;
  final DateTime createdAt;

  Resource({
    required this.id,
    required this.name,
    required this.description,
    this.website,
    required this.createdAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      website: json['website'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'website': website,
    };
  }
}
