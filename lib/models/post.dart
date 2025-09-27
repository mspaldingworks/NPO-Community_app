import 'package:transconnect/models/comment.dart';

class Post {
  final int id;
  final String? title;
  final String? body;
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

    // The API sends 'user' as a string for the username and may not send other author details.
    // We will parse what's available and use defaults for the rest.
    final authorUsername = json['user'] as String? ?? json['author_username'] as String? ?? 'Anonymous';
    final authorId = json['author'] as int?;
    final authorProfilePic = json['author_profile_pic'] as String?;
    final authorIsStaff = json['author_is_staff'] as bool? ?? false;

    // Safely handle emojis list
    final emojisData = json['emojis'] as List?;
    final emojisList = emojisData != null
        ? emojisData.map((emoji) => emoji.toString()).toList()
        : <String>[];

    return Post(
      id: json['id'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
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