class Resource {
  final int id;
  final String? user;
  final String? name;
  final String? description;
  final String? phoneNumber;
  final String? type;
  final String? url;
  final String? pubDate;
  final bool? public;
  final List<String> tags;

  Resource({
    required this.id,
    this.user,
    this.name,
    this.description,
    this.phoneNumber,
    this.type,
    this.url,
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
      phoneNumber: json['phone_number'] as String?,
      type: json['type'] as String?,
      url: json['url'] as String?,
      pubDate: json['pub_date'] as String?,
      public: json['public'] as bool?,
      tags: tags,
    );
  }
}