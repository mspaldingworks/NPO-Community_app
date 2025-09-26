import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/models/post.dart';

class CommunityService extends ApiClient {
  CommunityService();

  /// Fetches all groups.
  /// Uses inherited `authHeaders` and `read` method which handles response processing.
  Future<List<Group>> fetchGroups() async {
    final result = await read(
      urlPath: '/api/groups/',
      jsonHeaders: authHeaders,
    );
    
    final List<dynamic> data = result as List<dynamic>;
    return data.map((json) => Group.fromJson(json)).toList();
  }

  /// Fetches all posts.
  Future<List<Post>> fetchAllPosts() async {
    final result = await read(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
    );

    final List<dynamic> allPostsJson = result as List<dynamic>;
    return allPostsJson.map((json) => Post.fromJson(json)).toList();
  }

  /// Fetches all posts for a given group by its ID.
  /// NOTE: This still filters on the client-side as per the original implementation.
  Future<List<Post>> fetchPostsForGroup(int groupId) async {
    final result = await read(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
    );

    final List<dynamic> allPostsJson = result as List<dynamic>;
    final List<Post> allPosts = allPostsJson.map((json) => Post.fromJson(json)).toList();

    return allPosts.where((post) => post.groupId == groupId).toList();
  }

  /// Creates a new post.
  Future<Post> createPost({
    required String title,
    required String body,
    String? emoji,
    String? statusMessage,
    required bool public,
  }) async {
    final result = await post(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'title': title,
        'body': body,
        'emoji': emoji,
        'status_message': statusMessage,
        'public': public,
      },
      expectedStatusCode: 201,
    );
    return Post.fromJson(result as Map<String, dynamic>);
  }

  /// Fetches a single post by its ID.
  Future<Post> fetchPostById(int postId) async {
    final result = await read(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: authHeaders,
    );
    
    return Post.fromJson(result as Map<String, dynamic>);
  }

  /// Fetches a single group by its ID.
  Future<Group> fetchGroupById(int groupId) async {
    final result = await read(
      urlPath: '/api/groups/$groupId/',
      jsonHeaders: authHeaders,
    );
    return Group.fromJson(result as Map<String, dynamic>);
  }

  /// Creates a new group.
  Future<Group> createGroup({
    required String name,
    required String description,
    String? avatarUrl,
  }) async {
    final result = await post(
      urlPath: '/api/groups/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'name': name,
        'description': description,
        'avatarUrl': avatarUrl,
      },
      expectedStatusCode: 201,
    );
    return Group.fromJson(result as Map<String, dynamic>);
  }

  /// Adds a new comment to a post.
  Future<Comment> addComment({required int postId, required String content}) async {
    final jsonPayload = {
      'content': content,
      'post': postId,
    };
    
    final result = await post(
      urlPath: '/api/comments/',
      jsonHeaders: authHeaders,
      jsonPayload: jsonPayload,
      expectedStatusCode: 201, 
    );

    return Comment.fromJson(result as Map<String, dynamic>);
  }

  /// Fetches all comments.
  Future<List<Comment>> fetchAllComments() async {
    final result = await read(
      urlPath: '/api/comments/',
      jsonHeaders: authHeaders,
    );
    final List<dynamic> data = result as List<dynamic>;
    return data.map((json) => Comment.fromJson(json)).toList();
  }

  /// Fetches a single comment by its ID.
  Future<Comment> fetchCommentById(int commentId) async {
    final result = await read(
      urlPath: '/api/comments/$commentId/',
      jsonHeaders: authHeaders,
    );
    return Comment.fromJson(result as Map<String, dynamic>);
  }

  /// Updates a comment.
  Future<Comment> updateComment(int commentId, Map<String, dynamic> updates) async {
    final result = await update(
      urlPath: '/api/comments/$commentId/',
      jsonHeaders: authHeaders,
      jsonPayload: updates,
    );
    return Comment.fromJson(result as Map<String, dynamic>);
  }

  /// Deletes a comment.
  Future<void> deleteComment(int commentId) async {
    await delete(
      urlPath: '/api/comments/$commentId/',
      jsonHeaders: authHeaders,
    );
  }
}