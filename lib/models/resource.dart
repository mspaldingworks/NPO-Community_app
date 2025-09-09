import 'package:flutter/widgets.dart';

class Resource {
  final int id;
  final String user;
  final String name;
  final String type;
  final String url;
  final String pubDate;
  final bool public;

  Resource(
      {required this.id,
      required this.user,
      required this.name,
      required this.type,
      required this.url,
      required this.pubDate,
      required this.public});

  /// A factory constructor to create a `Resource` instance from a JSON map.
  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] as int,
      user: json['user'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      pubDate: json['pub_date'] as String,
      public: json['public'] as bool,
    );
  }
}