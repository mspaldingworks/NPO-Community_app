import 'package:transconnect/models/user.dart';

class FriendRequest {
  final int id;
  final Friend fromUser;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUser,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      fromUser: Friend.fromJson(json['from_user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
