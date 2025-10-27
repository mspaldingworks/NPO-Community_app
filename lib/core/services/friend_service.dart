import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:transconnect/models/user.dart';

/// A service class to manage all friend-related API requests.
/// It inherits authentication and response processing from ApiClient.
class FriendService extends ApiClient {
  static const String _friendsBasePath = 'api/friends';
  static const String _requestsPath = 'requests/';
  static const String _searchPath = 'search/';
  static const String _usersPath = 'api/users/';

  FriendService();

  /// Searches for users who are not currently friends and not involved in a pending request.
  /// Returns a list of `Friend` models.
  Future<List<Friend>> searchFriends(String query) async {
    final urlPath = '$_friendsBasePath/$_searchPath?q=$query';
    try {
      final result = await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
      );

      if (result is List) {
        return result
            .map((userJson) => Friend.fromJson(userJson as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error searching friends: $e\n$stackTrace');
      return [];
    }
  }

  /// Sends a friend request to a user by their username.
  Future<Map<String, dynamic>> sendFriendRequest(String username) async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final payload = {'username': username};

    final result = await post(
      urlPath: urlPath,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
    );
    return result as Map<String, dynamic>;
  }

  /// Retrieves all pending friend requests received by the current user.
  Future<List<FriendRequest>> listPendingRequests() async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    try {
      final result = await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
      );

      if (result is List) {
        return result
            .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error fetching pending requests: $e\n$stackTrace');
      return [];
    }
  }

  /// Accepts a pending friend request from the provided username.
  Future<Map<String, dynamic>> acceptFriendRequest(String username) async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final payload = {'username': username, 'action': 'accept'};

    final result = await update(
      urlPath: urlPath,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
    );
    return result as Map<String, dynamic>;
  }

  /// Declines a pending friend request from the provided username.
  Future<void> declineFriendRequest(String username) async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final payload = {'username': username, 'action': 'decline'};

    await update(
      urlPath: urlPath,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
      expectedStatusCode: 204,
    );
  }

  /// Retrieves the current user's friends list.
  Future<List<Friend>> listFriends() async {
    final urlPath = '$_friendsBasePath/';
    try {
      final result = await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
      );

      if (result is List) {
        return result
            .map((json) => Friend.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error fetching friends: $e\n$stackTrace');
      return [];
    }
  }

  /// Removes the friend with the provided username.
  Future<bool> removeFriend(String username) async {
    try {
      final urlPath = '$_friendsBasePath/$username/';
      await delete(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        expectedStatusCode: 204,
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error removing friend $username: $e\n$stackTrace');
      return false;
    }
  }
}