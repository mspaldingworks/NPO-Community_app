import 'package:meta/meta.dart';

@immutable
class PostNotification {
  final int postId;
  final String? title;
  final String? postEmoji;
  final int unreadCommentCount;
  final int unreadMentionCount;
  final DateTime? latestUnreadAt;

  const PostNotification({
    required this.postId,
    this.title,
    this.postEmoji,
    this.unreadCommentCount = 0,
    this.unreadMentionCount = 0,
    this.latestUnreadAt,
  });

  factory PostNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parsedLatest;
    final latestRaw = json['latest_unread_at'];
    if (latestRaw is String && latestRaw.isNotEmpty) {
      try {
        parsedLatest = DateTime.parse(latestRaw).toLocal();
      } catch (_) {
        parsedLatest = null;
      }
    }

    return PostNotification(
      postId: json['post_id'] is int
          ? json['post_id'] as int
          : int.tryParse(json['post_id'].toString()) ?? 0,
      title: json['title'] as String?,
      postEmoji: json['post_emoji'] as String?,
      unreadCommentCount: json['unread_comment_count'] is int
          ? json['unread_comment_count'] as int
          : int.tryParse(json['unread_comment_count'].toString()) ?? 0,
      unreadMentionCount: json['unread_mention_count'] is int
          ? json['unread_mention_count'] as int
          : int.tryParse(json['unread_mention_count'].toString()) ?? 0,
      latestUnreadAt: parsedLatest,
    );
  }

  bool get hasUnread => unreadCommentCount > 0 || unreadMentionCount > 0;

  int get totalUnread => unreadCommentCount + unreadMentionCount;
}
