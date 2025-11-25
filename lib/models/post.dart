import 'package:transconnect/models/comment.dart';

class Post {
  final int id;
  final String? title;
  final String? body;
  final String? emoji;
  final String? statusMessage;
  final bool? public;
  final int? author;
  final String? authorUsername;
  final String? authorProfilePic;
  final bool authorIsStaff;
  final String? pubDate;
  final String? updatedAt;
  final int? groupId;
  final List<Comment> comments;
  final List<String> emojis;
  final bool isAnonymous;

  Post({
    required this.id,
    this.title,
    this.body,
    this.emoji,
    this.statusMessage,
    this.public,
    this.author,
    this.authorUsername,
    this.authorProfilePic,
    this.authorIsStaff = false,
    this.pubDate,
    this.updatedAt,
    this.groupId,
    required this.comments,
    this.emojis = const [],
    this.isAnonymous = false,
  });

  bool get isEdited =>
      updatedAt != null && updatedAt!.isNotEmpty && updatedAt != pubDate;

  factory Post.fromJson(Map<String, dynamic> json) {
    var commentsList = json['comments'] as List? ?? [];
    List<Comment> comments = commentsList.map((i) => Comment.fromJson(i)).toList();

    // Robustly parse the group ID
    final dynamic groupValue = json['group'];
    int? groupId;
    if (groupValue is int) {
      groupId = groupValue;
    } else if (groupValue is String) {
      groupId = int.tryParse(groupValue);
    }

    // Robustly parse the author ID
    final dynamic authorValue = json['author'];
    int? authorId;
    if (authorValue is int) {
      authorId = authorValue;
    } else if (authorValue is String) {
      authorId = int.tryParse(authorValue);
    } else if (authorValue is Map) {
      final dynamic nestedId = authorValue['id'] ?? authorValue['user_id'] ?? authorValue['pk'];
      if (nestedId is int) {
        authorId = nestedId;
      } else if (nestedId is String) {
        authorId = int.tryParse(nestedId);
      }
    }

    authorId ??= json['author_id'] as int?;
    authorId ??= json['user_id'] as int?;

    final authorUsername = json['author_username'] as String?
        ?? json['author_display_name'] as String?
        ?? json['author_name'] as String?
        ?? json['created_by'] as String?
        ?? json['user'] as String?
        ?? (json['author'] is Map
            ? ((json['author'] as Map)['username'] as String?
                ?? (json['author'] as Map)['display_name'] as String?
                ?? (json['author'] as Map)['name'] as String?)
            : null);

    final authorProfilePic = json['author_profile_pic'] as String?
        ?? json['author_avatar'] as String?
        ?? json['author_profile_image'] as String?
        ?? (json['author'] is Map
            ? ((json['author'] as Map)['profile_pic'] as String?
                ?? (json['author'] as Map)['avatar'] as String?)
            : null);

    final authorIsStaff = json['author_is_staff'] as bool? ??
        (json['author'] is Map ? (json['author'] as Map)['is_staff'] as bool? : false) ??
        false;

    final emojisData = json['emojis'] as List?;
    final List<String> emojisList = emojisData != null
        ? emojisData.map((emoji) => emoji.toString()).toList()
        : <String>[];

    final String? primaryEmoji = (json['emoji'] as String?)?.trim();
    if (primaryEmoji != null && primaryEmoji.isNotEmpty && !emojisList.contains(primaryEmoji)) {
      emojisList.insert(0, primaryEmoji);
    }

    final String? updatedAt = json['updated_at'] as String?
        ?? json['modified_at'] as String?
        ?? json['edited_at'] as String?;

    final isAnonymous = (json['anonymous'] as bool?) ??
        (json['is_anonymous'] as bool?) ??
        false;

    return Post(
      id: json['id'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
      emoji: json['emoji'] as String?,
      statusMessage: json['status_message'] as String?,
      public: json['public'] as bool?,
      author: authorId,
      authorUsername: authorUsername,
      authorProfilePic: authorProfilePic,
      authorIsStaff: authorIsStaff,
      pubDate: json['pub_date'] as String?,
      updatedAt: updatedAt,
      groupId: groupId,
      comments: comments,
      emojis: emojisList,
      isAnonymous: isAnonymous,
    );
  }
}