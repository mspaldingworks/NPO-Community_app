import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingGuide {
  final String id;
  final String title;
  final String created;
  final List<String> authors;
  final List<String> tags;
  // Fields for different guide types, can be null
  final List<Map<String, dynamic>>? sections;
  final List<String>? keyMessaging;
  final List<String>? avoid;
  final List<String>? impacts;
  final List<String>? criticalDataLinks;

  MessagingGuide({
    required this.id,
    required this.title,
    required this.created,
    required this.authors,
    required this.tags,
    this.sections,
    this.keyMessaging,
    this.avoid,
    this.impacts,
    this.criticalDataLinks,
  });

  factory MessagingGuide.fromJson(Map<String, dynamic> json) {
    return MessagingGuide(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      created: json['created'] ?? '',
      authors: List<String>.from(json['authors'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      sections: json['sections'] != null ? List<Map<String, dynamic>>.from(json['sections']) : null,
      keyMessaging: json['key_messaging'] != null ? List<String>.from(json['key_messaging']) : null,
      avoid: json['avoid'] != null ? List<String>.from(json['avoid']) : null,
      impacts: json['impacts'] != null ? List<String>.from(json['impacts']) : null,
      criticalDataLinks: json['critical_data_links'] != null ? List<String>.from(json['critical_data_links']) : null,
    );
  }
}
