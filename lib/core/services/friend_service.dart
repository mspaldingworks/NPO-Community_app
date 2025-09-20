import 'dart:async';
import 'dart:convert';

import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/user.dart';

class FriendService extends ApiClient {
  final AuthService _authService = AuthService();

  /// Searches for users by username.
  Future<List<User>> searchUsers(String query) async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: 'api/users/search/?q=$query',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search for users: ${response.body}');
    }
  }

  /// Fetches the list of friends for the current user.
  Future<List<User>> fetchFriends() async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: 'api/friends/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch friends: ${response.body}');
    }
  }

  /// Sends a friend request to another user.
  Future<void> sendFriendRequest(String toUserId) async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await post(
      urlPath: 'api/friend-requests/',
      jsonHeaders: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      jsonPayload: {'to_user_id': toUserId},
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send friend request: ${response.body}');
    }
  }

  /// Fetches pending friend requests.
  Future<List<dynamic>> fetchFriendRequests() async {
    // TODO: Implement GET /api/friend-requests/
    return [];
  }

  /// Responds to a friend request.
  Future<void> respondToFriendRequest(String requestId, String action) async {
    // TODO: Implement PUT /api/friend-requests/{request_id}/
  }

  /// Removes a friend.
  Future<void> removeFriend(String friendId) async {
    // TODO: Implement DELETE /api/friends/{friend_id}/
  }
}
