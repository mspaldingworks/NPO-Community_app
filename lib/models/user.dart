import 'package:flutter/widgets.dart';

class User {
  final String uid;
  final String username;
  final String email;
  final String city;
  final String? statusMessage;
  final String? flair;
  final String? profilePic;
  final String token;

  User(
      {required this.uid,
      required this.username,
      required this.email,
      required this.city,
      this.statusMessage,
      this.flair,
      this.profilePic,
      required this.token});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['id'].toString(),
      username: json['username'],
      email: json['email'],
      city: json['city'],
      statusMessage: json['status_message'],
      flair: json['flair'],
      profilePic: json['profile_pic'],
      token: json['token'],
    );
  }
}
