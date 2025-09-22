import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/models/post.dart';

class CommunityService extends ApiClient {
  final AuthService authService;

  CommunityService({required this.authService});

  Future<List<Group>> fetchGroups() async {
    final token = authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: '/api/groups/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load groups');
    }
  }

  // Fetches all posts for a given group by its ID.
  Future<List<Post>> fetchPostsForGroup(int groupId) async {
    final token = authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: '/api/posts/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> allPostsJson = json.decode(response.body);
      final List<Post> allPosts = allPostsJson.map((json) => Post.fromJson(json)).toList();

      // Filter posts on the client-side by group ID
      return allPosts.where((post) => post.groupId == groupId).toList();
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Future<Post> fetchPostById(int postId) async {
    final token = authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return Post.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load post');
    }
  }

  Future<Comment> addComment({required int postId, required String content}) async {
    final token = authService.currentUser?.token;
    final user = authService.currentUser;

    if (token == null || user == null) {
      throw Exception('User not authenticated');
    }

    final response = await post(
      urlPath: '/api/comments/',
      jsonHeaders: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      jsonPayload: {
        'post': postId,
        'content': content
      },
    );

    if (response.statusCode == 201) {
      return Comment.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add comment. Status code: ${response.statusCode}');
    }
  }
}
