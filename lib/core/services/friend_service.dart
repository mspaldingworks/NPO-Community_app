import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';

/// A service class to manage all friend-related API requests.
/// It inherits authentication and response processing from ApiClient.
class FriendService extends ApiClient {
  static const String _friendsBasePath = 'api/friends';
  static const String _requestsPath = 'requests/';
  static const String _searchPath = 'search/';
  static const String _usersPath = 'api/users/';

  FriendService(); 

  // --- Friends Endpoints ---

  /// Searches for users who are not currently friends and not involved in a pending request.
  /// Returns a list of user maps.
  Future<List<User>> searchFriends(String query) async {
    try {
      final urlPath = '$_friendsBasePath/$_searchPath?q=$query';
      
      // 1. Call the inherited read method. It returns the decoded body (List<dynamic>) or throws an exception.
      final result = await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders, // Inherited from ApiClient
      );
  
      // 2. Validate the result is a list.
      if (result is List) {
        // 3. Map the decoded list of dynamic objects to a List<User>.
        final List<User> users = result
            .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
            .toList();
            
        return users;
      } else {
        // Return an empty list if the successful response was not a list.
        return []; 
      }
    } catch (e) {
      // Catch any exceptions thrown by read() (network errors, API errors)
      // and return an empty list on failure, as requested.
      // print('Error searching for friends: $e');
      return []; 
    }
  }

  /// Sends a friend request to a user by their username.
  /// Returns a map with the success detail.
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

  /// Retrieves a list of all pending friend requests received by the current user.
  /// Returns a list of friend request maps.
  Future<List<Map<String, dynamic>>> listPendingRequests() async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final result = await read(
      urlPath: urlPath,
      jsonHeaders: authHeaders,
    );
    return result as List<Map<String, dynamic>>;
  }

  /// Accepts a pending friend request from a specified username.
  /// Returns a map with the success detail.
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

  /// Declines a pending friend request from a specified username.
  /// Completes successfully if the 204 No Content status is received.
  Future<void> declineFriendRequest(String username) async {
    final urlPath = '$_friendsBasePath/$_requestsPath';
    final payload = {'username': username, 'action': 'decline'};

    // Explicitly set expectedStatusCode to 204 for the decline action.
    await update( 
      urlPath: urlPath,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
      expectedStatusCode: 204, 
    );
  }

  /// Retrieves a basic list of all users or null if an error occurs.
  Future<List<User>> getAllUsers() async {
    try {
      final result = await read(
        urlPath: _usersPath, // Assuming _usersPath is correctly defined as 'api/users/'
        jsonHeaders: authHeaders, // Inherited from ApiClient
      );
      if (result is List) {
        if (result.isEmpty) {
          return []; // Return an empty list if the API returns an empty array.
        }
        final List<User> users = result
            .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
            .toList();

        return users;
      } else {
        return [];
      }
    } catch (e) {
      return []; // Return null as requested on failure
    }
  }
}