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
  final Bool public;
  final List<Comment>? comments;

  Post(
      {required this.id,
      required this.user,
      required this.group,
      required this.groupName,
      required this.title,
      required this.body,
      required this.emoji,
      required this.feeling,
      required this.pubDate,
      required this.public,
      this.comments
      });
}