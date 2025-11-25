class Resource {
  final int id;
  final String? user;
  final String? name;
  final String? description;
  final String? type;
  final String? url;
  final String? provider;
  final String? pubDate;
  final bool? public;
  final List<String> tags;

  Resource({
    required this.id,
    this.user,
    this.name,
    this.description,
    this.type,
    this.url,
    this.provider,
    this.pubDate,
    this.public,
    this.tags = const [],
  });

  /// A factory constructor to create a `Resource` instance from a JSON map.
  factory Resource.fromJson(Map<String, dynamic> json) {
    final tagsList = json['tags'] as List<dynamic>?;
    final tags = tagsList?.map((tag) => tag.toString()).toList() ?? [];

    return Resource(
      id: json['id'] as int,
      user: json['user'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      type: json['type'] as String?,
      url: json['url'] as String?,
      provider: json['provider'] as String?,
      pubDate: json['pub_date'] as String?,
      public: json['public'] as bool?,
      tags: tags,
    );
  }

  /// Converts a `Resource` instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'name': name,
      'description': description,
      'type': type,
      'url': url,
      'provider': provider,
      'pub_date': pubDate,
      'public': public,
      'tags': tags,
    };
  }
}