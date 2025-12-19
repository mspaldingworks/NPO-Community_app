import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/models/user.dart';

class CacheCollectionEvent {
  final String cacheId;
  final String cacheTitle;
  final String collectedByUsername;
  final int? collectedByUserId;
  final DateTime collectedAt;

  const CacheCollectionEvent({
    required this.cacheId,
    required this.cacheTitle,
    required this.collectedByUsername,
    required this.collectedByUserId,
    required this.collectedAt,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'cacheId': cacheId,
      'cacheTitle': cacheTitle,
      'collectedByUsername': collectedByUsername,
      'collectedByUserId': collectedByUserId,
      'collectedAt': collectedAt.toUtc().toIso8601String(),
    };
  }

  static CacheCollectionEvent fromJson(Map<String, Object?> json) {
    return CacheCollectionEvent(
      cacheId: json['cacheId'] as String,
      cacheTitle: json['cacheTitle'] as String? ?? 'Unknown cache',
      collectedByUsername: json['collectedByUsername'] as String? ?? 'Unknown',
      collectedByUserId: json['collectedByUserId'] as int?,
      collectedAt: DateTime.parse(json['collectedAt'] as String).toLocal(),
    );
  }
}

class CacheCollections {
  static const String _eventsKey = 'cache_collection_events';
  static const String _unreadKey = 'cache_collection_unread';

  static Future<List<CacheCollectionEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.trim().isEmpty) return const <CacheCollectionEvent>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <CacheCollectionEvent>[];

    final events = <CacheCollectionEvent>[];
    for (final item in decoded) {
      if (item is Map) {
        final map = Map<String, Object?>.from(item);
        events.add(CacheCollectionEvent.fromJson(map));
      }
    }

    events.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    return events;
  }

  static Future<bool> addCollection({required Geocache cache, required User? user, bool markUnread = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await getEvents();

    final username = user?.username ?? 'Unknown';
    final userId = user?.id;

    final already = events.any(
      (e) => e.cacheId == cache.id && e.collectedByUsername == username,
    );
    if (already) return false;

    final next = <CacheCollectionEvent>[
      CacheCollectionEvent(
        cacheId: cache.id,
        cacheTitle: cache.title,
        collectedByUsername: username,
        collectedByUserId: userId,
        collectedAt: DateTime.now(),
      ),
      ...events,
    ];

    final encoded = jsonEncode(next.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, encoded);
    if (markUnread) {
      await prefs.setBool(_unreadKey, true);
    }
    return true;
  }

  static Future<bool> hasUnread() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unreadKey) ?? false;
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unreadKey, false);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.setBool(_unreadKey, false);
  }
}
