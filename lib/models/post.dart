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
  final int? groupId;
  final List<Comment> comments;
  final List<String> emojis;

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
    this.groupId,
    required this.comments,
    this.emojis = const [],
  });

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
      final dynamic nestedId = authorValue['id'];
      if (nestedId is int) {
        authorId = nestedId;
      } else if (nestedId is String) {
        authorId = int.tryParse(nestedId);
      }
    }

    final authorUsername = json['author_username'] as String? ??
        (json['author'] is Map ? (json['author'] as Map)['username'] as String? : null);

    final authorProfilePic = json['author_profile_pic'] as String? ??
        (json['author'] is Map ? (json['author'] as Map)['profile_pic'] as String? : null);

    final authorIsStaff = json['author_is_staff'] as bool? ??
        (json['author'] is Map ? (json['author'] as Map)['is_staff'] as bool? : false) ??
        false;

    final emojisData = json['emojis'] as List?;
    final emojisList = emojisData != null
        ? emojisData.map((emoji) => emoji.toString()).toList()
        : <String>[];

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
      groupId: groupId,
      comments: comments,
      emojis: emojisList,
    );
  }
}