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

  static const List<String> _friendListCandidates = <String>[
    'api/friends/',
    'api/friendships/',
    'api/friends/list/',
    'api/friendships/list/',
  ];

  static const List<String> _friendRequestIncomingCandidates = <String>[
    'api/friends/requests/',
    'api/friendships/requests/',
    'api/friend-requests/',
    'api/friendrequests/',
    'api/friendships/pending/',
  ];

  static const List<String> _friendRequestOutgoingCandidates = <String>[
    'api/friends/sent/',
    'api/friendships/sent/',
    'api/friends/outgoing/',
    'api/friendships/outgoing/',
  ];

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

  bool _is404Error(Object error) {
    final message = error.toString();
    return message.contains('Status 404') || message.contains('status 404');
  }

  Future<dynamic> _readWithFallback(List<String> urlPaths) async {
    for (final path in urlPaths) {
      try {
        return await read(
          urlPath: path,
          jsonHeaders: authHeaders,
        );
      } catch (e, stackTrace) {
        if (_is404Error(e)) {
          debugPrint('FriendService read fallback 404 for $path');
          continue;
        }
        debugPrint('FriendService read failed for $path: $e\n$stackTrace');
      }
    }
    return null;
  }

  Future<dynamic> _updateWithFallback(
    List<String> urlPaths,
    Map<String, dynamic> payload, {
    int expectedStatusCode = 200,
  }) async {
    for (final path in urlPaths) {
      try {
        return await update(
          urlPath: path,
          jsonHeaders: authHeaders,
          jsonPayload: payload,
          expectedStatusCode: expectedStatusCode,
        );
      } catch (e, stackTrace) {
        if (_is404Error(e)) {
          debugPrint('FriendService update fallback 404 for $path');
          continue;
        }
        debugPrint('FriendService update failed for $path: $e\n$stackTrace');
        rethrow;
      }
    }
    throw Exception('FriendService update failed for all candidate endpoints.');
  }

  Future<bool> _deleteWithFallback(List<String> urlPaths) async {
    for (final path in urlPaths) {
      try {
        await delete(
          urlPath: path,
          jsonHeaders: authHeaders,
          expectedStatusCode: 204,
        );
        return true;
      } catch (e, stackTrace) {
        if (_is404Error(e)) {
          debugPrint('FriendService delete fallback 404 for $path');
          continue;
        }
        debugPrint('FriendService delete failed for $path: $e\n$stackTrace');
        rethrow;
      }
    }
    return false;
  }

  List<Friend> _parseFriendResults(dynamic result) {
    final List<dynamic> rawResults;
    if (result is List) {
      rawResults = result;
    } else if (result is Map<String, dynamic>) {
      final dynamic candidates =
          result['results'] ??
          result['data'] ??
          result['users'] ??
          result['items'] ??
          result['friends'];
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
    final incomingCandidates = <String>{
      '$_friendsBasePath/$_requestsPath',
      ..._friendRequestIncomingCandidates,
    };

    final outgoingCandidates = <String>{
      ..._friendRequestOutgoingCandidates,
    };

    try {
      final incoming = await _readWithFallback(incomingCandidates.toList());
      final outgoing = await _readWithFallback(outgoingCandidates.toList());

      final List<FriendRequest> requests = [];

      void addRequests(dynamic source, {bool isOutgoing = false}) {
        if (source is List) {
          requests.addAll(
            source
                .map((json) => FriendRequest.fromJson(json as Map<String, dynamic>))
                .map(
                  (req) => isOutgoing
                      ? FriendRequest(
                          id: req.id,
                          fromUser: req.fromUser,
                          toUser: req.toUser,
                          status: req.status ?? 'pending',
                          createdAt: req.createdAt,
                        )
                      : req,
                ),
          );
        } else if (source is Map<String, dynamic>) {
          final dynamic list = source['results'] ?? source['data'] ?? source['requests'];
          if (list is List) {
            addRequests(list, isOutgoing: isOutgoing);
          }
        }
      }

      addRequests(incoming);
      addRequests(outgoing, isOutgoing: true);

      // De-duplicate based on request id (if provided)
      final Map<int, FriendRequest> byId = {};
      final List<FriendRequest> results = [];
      for (final request in requests) {
        if (request.id != -1) {
          byId[request.id] = request;
        } else {
          results.add(request);
        }
      }

      results.addAll(byId.values);
      return results;
    } catch (e, stackTrace) {
      debugPrint('Error fetching pending requests: $e\n$stackTrace');
      return [];
    }
  }
  /// Accepts a pending friend request from the provided username.
  Future<Map<String, dynamic>> acceptFriendRequest(String username) async {
    final payload = {'username': username, 'action': 'accept'};
    final candidates = <String>{
      '$_friendsBasePath/$_requestsPath',
      ..._friendRequestIncomingCandidates,
      ..._friendRequestOutgoingCandidates,
    };

    final result = await _updateWithFallback(candidates.toList(), payload);
    return (result as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  /// Declines a pending friend request from the provided username.
  Future<void> declineFriendRequest(String username) async {
    final payload = {'username': username, 'action': 'decline'};
    final candidates = <String>{
      '$_friendsBasePath/$_requestsPath',
      ..._friendRequestIncomingCandidates,
      ..._friendRequestOutgoingCandidates,
    };

    await _updateWithFallback(candidates.toList(), payload, expectedStatusCode: 204);
  }

  /// Retrieves the current user's friends list.
  Future<List<Friend>> listFriends() async {
    final candidates = <String>{
      '$_friendsBasePath/',
      ..._friendListCandidates,
    };
    try {
      final result = await _readWithFallback(candidates.toList());
      if (result == null) {
        return [];
      }
      final parsed = _parseFriendResults(result);
      if (parsed.isNotEmpty) {
        return parsed;
      }

      if (result is Map<String, dynamic>) {
        final dynamic fallbackList = result['friends'] ?? result['data'];
        if (fallbackList is List) {
          return fallbackList
              .map((json) => Friend.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

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
    final candidates = <String>{
      '$_friendsBasePath/$username/',
      ..._friendListCandidates.map((base) => '$base$username/'),
    };

    try {
      return await _deleteWithFallback(candidates.toList());
    } catch (e, stackTrace) {
      debugPrint('Error removing friend $username: $e\n$stackTrace');
      return false;
    }
  }
}