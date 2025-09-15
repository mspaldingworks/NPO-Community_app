import 'dart:ffi';
import 'package:flutter/widgets.dart';
import 'package:transconnect/models/comment.dart';

class Post {
  final int id;
  final String user;
  final int group;
  final String groupName;
  final String title;
  final String body;
  final String emoji;
  final String feeling;
  final String pubDate;
  final bool public;
  final List<Comment>? comments;

  Post({
    required this.id,
    required this.user,
    required this.group,
    required this.groupName,
    required this.title,
    required this.body,
    required this.emoji,
    required this.feeling,
    required this.pubDate,
    required this.public,
    this.comments,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      user: json['user'],
      group: json['group'],
      groupName: json['group_name'],
      title: json['title'],
      body: json['body'],
      emoji: json['emoji'] ?? '',
      feeling: json['feeling'] ?? '',
      pubDate: json['pub_date'],
      public: json['public'],
      // Comments are optional and may not be in the list view
      comments: json['comments'] != null
          ? (json['comments'] as List).map((c) => Comment.fromJson(c)).toList()
          : null,
    );
  }
}