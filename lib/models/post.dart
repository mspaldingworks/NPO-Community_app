import 'package:transconnect/models/comment.dart';

class Post {
  final int id;
  final String? title;
  final String? body;
  final int? author;
  final String? authorUsername;
  final String? pubDate;
  final int? groupId;
  final List<Comment> comments;

  Post({
    required this.id,
    this.title,
    this.body,
    this.author,
    this.authorUsername,
    this.pubDate,
    this.groupId,
    required this.comments,
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
    }

    return Post(
      id: json['id'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
      author: authorId, // Use the parsed authorId
      authorUsername: json['author_username'] as String?,
      pubDate: json['pub_date'] as String?,
      groupId: groupId,
      comments: comments,
    );
  }
}