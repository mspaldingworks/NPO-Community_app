import 'dart:ffi';
import 'package:flutter/widgets.dart';

class Resrouce {
  final int id;
  final String user;
  final String name;
  final String type;
  final String url;
  final String pubDate;
  final Bool public;

  Resrouce(
      {required this.id,
      required this.user,
      required this.name,
      required this.type,
      required this.url,
      required this.pubDate,
      required this.public});
}