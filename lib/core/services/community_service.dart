import 'package:transconnect/core/services/api_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:transconnect/core/constants/api_endpoints.dart';
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

  /// Adds a new comment with an optional single image (image) via multipart.
  Future<Comment> addCommentMultipart({
    required int postId,
    required String content,
    bool anonymous = false,
    String? imageFilePath,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.host}/api/comments/');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Token $authToken'
      ..fields['post'] = postId.toString()
      ..fields['content'] = content
      ..fields['anonymous'] = anonymous.toString();

    if (imageFilePath != null && imageFilePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFilePath));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to add comment: ${response.statusCode} ${response.body}');
    }
    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    return Comment.fromJson(json);
  }

  /// Creates a new post with optional images via multipart/form-data.
  /// Field names follow the agreed contract: images[] for multiple images.
  Future<Post> createPostMultipart({
    required int groupId,
    required String title,
    required String body,
    required String emoji,
    required bool public,
    bool anonymous = false,
    List<String> imageFilePaths = const [],
  }) async {
    final uri = Uri.parse('${ApiEndpoints.host}/api/posts/');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Token $authToken'
      ..fields['group'] = groupId.toString()
      ..fields['title'] = title
      ..fields['body'] = body
      ..fields['emoji'] = emoji
      ..fields['public'] = public.toString()
      ..fields['anonymous'] = anonymous.toString();

    // Attach up to 4 images (client should enforce limit; keep extra safety here)
    final files = imageFilePaths.take(4);
    for (final path in files) {
      request.files.add(await http.MultipartFile.fromPath('images[]', path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to create post: ${response.statusCode} ${response.body}');
    }
    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    return Post.fromJson(json);
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
    required int groupId,
    required String title,
    required String body,
    required String feeling,
    List<String> emojis = const [],
    required bool public,
    bool anonymous = false,
  }) async {
    final result = await post(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'group': groupId,
        'title': title,
        'body': body,
        'feeling': feeling,
        'emoji': emojis.isNotEmpty ? emojis.first : null,
        'emojis': emojis, 
        'public': public,
        'anonymous': anonymous,
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

  /// Creates a new status post.
  Future<Post> createStatusPost({
    required String title,
    required String body,
    required String emoji,
    required String statusMessage,
    required bool public,
  }) async {
    final jsonPayload = {
      'title': title,
      'body': body,
      'emoji': emoji,
      'status_message': statusMessage,
      'public': public,
    };

    final result = await post(
      urlPath: '/api/posts/',
      jsonHeaders: authHeaders,
      jsonPayload: jsonPayload,
      expectedStatusCode: 201,
    );

    return Post.fromJson(result as Map<String, dynamic>);
  }

  /// Adds a new comment to a post.
  Future<Comment> addComment({
    required int postId,
    required String content,
    bool anonymous = false,
  }) async {
    final jsonPayload = {
      'post': postId,
      'content': content,
      'anonymous': anonymous,
    };

    // The post method handles Content-Type (via authHeaders) and checks for 201 Created.
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

  /// Updates a post.
  Future<Post> updatePost(int postId, Map<String, dynamic> updates) async {
    final result = await update(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: authHeaders,
      jsonPayload: updates,
    );
    return Post.fromJson(result as Map<String, dynamic>);
  }

  /// Deletes a post.
  Future<void> deletePost(int postId) async {
    await delete(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: authHeaders,
    );
  }
}