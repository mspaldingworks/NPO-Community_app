import 'dart:async';

import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';

class FriendService extends ApiClient {
  // TODO: Implement with api.luxashome.com

  /// Searches for users by username.
  Future<List<User>> searchUsers(String query) async {
    // TODO: Implement GET /api/users/search/?q={query}
    return [];
  }

  /// Fetches the list of friends for the current user.
  Future<List<User>> fetchFriends() async {
    // TODO: Implement GET /api/friends/
    return [];
  }

  /// Sends a friend request to another user.
  Future<void> sendFriendRequest(String toUserId) async {
    // TODO: Implement POST /api/friend-requests/
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
