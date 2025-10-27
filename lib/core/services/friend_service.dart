import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:transconnect/models/user.dart';

/// A service class to manage all friend-related API requests.
/// It inherits authentication and response processing from ApiClient.
class FriendService extends ApiClient {
  static const String _friendsBasePath = '/api/friends';
  static const String _requestsPath = 'requests/';
  static const String _searchPath = 'search/';
  static const String _usersPath = 'api/users/';

  FriendService();

  /// Searches for users who are not currently friends and not involved in a pending request.
  /// Returns a list of `Friend` models.
  Future<List<Friend>> searchFriends(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    final encodedQuery = Uri.encodeQueryComponent(trimmedQuery);
    final candidatePaths = <String>{
      '$_friendsBasePath/$_searchPath?q=$encodedQuery',
      '$_friendsBasePath/$_searchPath?search=$encodedQuery',
      '$_friendsBasePath/$_searchPath?username=$encodedQuery',
      '$_usersPath?search=$encodedQuery',
      '$_usersPath?username=$encodedQuery',
    };

    final queryLower = trimmedQuery.toLowerCase();

    for (final path in candidatePaths) {
      final result = await _safeRead(path);
      if (result == null) {
        continue;
      }

      final friends = _filterByPrefix(_parseFriendResults(result), queryLower);
      if (friends.isNotEmpty) {
        return friends;
      }
    }

    final allUsersResult = await _safeRead('$_usersPath');
    if (allUsersResult != null) {
      final filtered = _filterByPrefix(_parseFriendResults(allUsersResult), queryLower);
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }

    debugPrint('Friend search returned no results for query "$trimmedQuery"');
    return [];
  }

  Future<dynamic> _safeRead(String urlPath) async {
    try {
      return await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
      );
    } catch (e, stackTrace) {
      debugPrint('Friend search request failed for $urlPath: $e\n$stackTrace');
      return null;
    }
  }

  List<Friend> _parseFriendResults(dynamic result) {
    final List<dynamic> rawResults;
    if (result is List) {
      rawResults = result;
    } else if (result is Map<String, dynamic>) {
      final dynamic candidates =
          result['results'] ?? result['data'] ?? result['users'] ?? result['items'];
      if (candidates is List) {
        rawResults = candidates;
      } else if (candidates is Map<String, dynamic>) {
        rawResults = [candidates];
      } else {
        rawResults = const [];
      }
    } else {
      rawResults = const [];
    }

    final Map<int, Friend> deduped = {};
    for (final entry in rawResults) {
      if (entry is Map<String, dynamic>) {
        try {
          final friend = Friend.fromJson(entry);
          deduped[friend.id] = friend;
        } catch (e, stackTrace) {
          debugPrint('Failed to parse friend entry $entry: $e\n$stackTrace');
        }
      }
    }

    return deduped.values.toList();
  }

  List<Friend> _filterByPrefix(List<Friend> friends, String queryLower) {
    if (queryLower.isEmpty) {
      return friends;
    }
    return friends
        .where((friend) => friend.username.toLowerCase().startsWith(queryLower))
        .toList();
  }

  /// Sends a friend request to a user by their username.
  Future<Map<String, dynamic>> sendFriendRequest(String username) async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final payload = {'username': username};

    try {
      final result = await post(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        jsonPayload: payload,
        expectedStatusCode: 201,
      );
      return (result as Map<String, dynamic>?) ?? {'detail': 'Friend request sent.'};
    } on Exception catch (e) {
      final message = e.toString();

      if (message.contains('Status 200')) {
        return {'detail': 'Friend request sent.'};
      }

      if (message.contains('Friend request sent to')) {
        return {'detail': message};
      }

      if (message.contains('already friends') ||
          message.contains('pending friend request') ||
          message.contains('already pending')) {
        return {'detail': message};
      }

      rethrow;
    }
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