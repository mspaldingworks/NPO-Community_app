import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/models/post.dart';
// Removed: import 'package:http/http.dart' as http;
// Removed: import 'dart:convert';
// Removed: import 'package:transconnect/core/services/auth_service.dart';

class CommunityService extends ApiClient {
  // Removed: final AuthService authService;
  // Removed: CommunityService({required this.authService});
  
  // Simple constructor, implicitly calls ApiClient()
  CommunityService();

  /// Fetches all groups.
  /// Uses inherited `authHeaders` and `read` method which handles response processing.
  Future<List<Group>> fetchGroups() async {
    // The inherited `authHeaders` will throw an exception if the token is missing.
    final result = await read(
      urlPath: '/api/groups/',
      jsonHeaders: authHeaders,
    );
    
    // The result is the decoded JSON body (List<dynamic> in this case).
    final List<dynamic> data = result as List<dynamic>;
    return data.map((json) => Group.fromJson(json)).toList();
  }

  /// Fetches all posts for a given group by its ID.
  /// NOTE: This still filters on the client-side as per the original implementation.
  Future<List<Post>> fetchPostsForGroup(int groupId) async {
    final result = await read(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
    );

    // The result is the decoded JSON body (List<dynamic> in this case).
    final List<dynamic> allPostsJson = result as List<dynamic>;
    final List<Post> allPosts = allPostsJson.map((json) => Post.fromJson(json)).toList();

    // Filter posts on the client-side by group ID
    return allPosts.where((post) => post.groupId == groupId).toList();
  }

  /// Fetches a single post by its ID.
  Future<Post> fetchPostById(int postId) async {
    final result = await read(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: authHeaders,
    );
    
    // The result is the decoded JSON body (Map<String, dynamic> in this case).
    return Post.fromJson(result as Map<String, dynamic>);
  }

  /// Adds a new comment to a post.
  Future<Comment> addComment({required int postId, required String content}) async {
    final jsonPayload = {
      'content': content,
      'post': postId,
    };
    
    // The post method now handles Content-Type (via authHeaders) and checks for 201 Created.
    final result = await post(
      urlPath: '/api/comments/',
      jsonHeaders: authHeaders,
      jsonPayload: jsonPayload,
      expectedStatusCode: 201, // Expect a 201 Created status
    );

    // The result is the decoded JSON body (Map<String, dynamic> in this case).
    return Comment.fromJson(result as Map<String, dynamic>);
  }
}