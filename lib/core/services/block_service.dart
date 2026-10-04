import 'package:npo_community/core/services/api_client.dart';

class BlockedMember {
  const BlockedMember({
    required this.id,
    required this.username,
    required this.displayName,
    this.blockedAt,
  });

  final int id;
  final String username;
  final String displayName;
  final DateTime? blockedAt;

  factory BlockedMember.fromJson(Map<String, dynamic> json) => BlockedMember(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    displayName:
        json['display_name'] as String? ?? json['username'] as String? ?? '',
    blockedAt: json['blocked_at'] is String
        ? DateTime.tryParse(json['blocked_at'] as String)?.toLocal()
        : null,
  );
}

/// Member blocks (`/api/blocks/`). Blocking is private and mutual: neither
/// member sees or can contact the other until the block is lifted.
class BlockService extends ApiClient {
  BlockService();

  Future<List<BlockedMember>> fetchBlocked() async {
    final data = await read(urlPath: '/api/blocks/', jsonHeaders: authHeaders);
    return [
      for (final row in (data as List))
        BlockedMember.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<void> block(int userId) async {
    await post(
      urlPath: '/api/blocks/',
      jsonHeaders: authHeaders,
      jsonPayload: {'user_id': userId},
      expectedStatusCode: 201,
    );
  }

  Future<void> unblock(int userId) async {
    await delete(urlPath: '/api/blocks/$userId/', jsonHeaders: authHeaders);
  }
}
