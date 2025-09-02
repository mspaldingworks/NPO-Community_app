import 'package:cloud_firestore/cloud_firestore.dart';

class Issue {
  final String id;
  final String title;
  final List<String> tags;
  final List<String> keyMessaging;
  final List<String> avoid;
  final List<String> impacts;

  Issue({
    required this.id,
    required this.title,
    required this.tags,
    required this.keyMessaging,
    required this.avoid,
    required this.impacts,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      keyMessaging: List<String>.from(json['key_messaging'] ?? []),
      avoid: List<String>.from(json['avoid'] ?? []),
      impacts: List<String>.from(json['impacts'] ?? []),
    );
  }
}
