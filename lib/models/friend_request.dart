import 'package:npo_community/models/user.dart';

class FriendRequest {
  final int id;
  final Friend fromUser;
  final Friend? toUser;
  final String? status;
  final DateTime? createdAt;

  FriendRequest({
    required this.id,
    required this.fromUser,
    this.toUser,
    this.status,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    Friend? parseFriend(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Friend.fromJson(value);
      }
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        try {
          return DateTime.parse(value).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return FriendRequest(
      id: json['id'] is int
          ? json['id'] as int
          : int.parse(json['id'].toString()),
      fromUser:
          parseFriend(json['from_user']) ??
          parseFriend(json['from']) ??
          Friend(
            id: -1,
            username: json['from_username'] as String? ?? 'unknown',
            email: '',
            profilePic: json['from_user_pic'] as String?,
          ),
      toUser:
          parseFriend(json['to_user']) ??
          parseFriend(json['to']) ??
          (json['to_username'] != null
              ? Friend(
                  id: -1,
                  username: json['to_username'] as String,
                  email: '',
                  profilePic: json['to_user_pic'] as String? ?? '',
                )
              : null),
      status: json['status'] as String? ?? json['state'] as String?,
      createdAt: parseDate(json['created_at'] ?? json['timestamp']),
    );
  }
}
