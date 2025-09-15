import 'package:flutter/widgets.dart';

class Comment {
  final int id;
  final String user;
  final int post;
  final String content;
  final String pubDate;

  Comment({
    required this.id,
    required this.user,
    required this.post,
    required this.content,
    required this.pubDate,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      user: json['user'],
      post: json['post'],
      content: json['content'],
      pubDate: json['pub_date'],
    );
  }
}