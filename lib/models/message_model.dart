import 'package:transconnect/models/user.dart';

class Message {
  final String id;
  final String channelId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final User? profile;

  Message({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.profile,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] == null ? null : User.fromJson(json['profiles']),
    );
  }
}
