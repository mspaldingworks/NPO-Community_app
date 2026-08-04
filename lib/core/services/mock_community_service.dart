import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/mock_api_client.dart';
import 'package:npo_community/models/comment.dart';
import 'package:npo_community/models/group.dart';
import 'package:npo_community/models/post.dart';

class MockCommunityService extends CommunityService {
  final MockApiClient _client = MockApiClient();

  @override
  Future<List<Group>> fetchGroups() async {
    final result = await _client.read(
      urlPath: '/api/groups/',
      jsonHeaders: const {},
    );

    final List<dynamic> data = (result as List?) ?? const [];
    return data
        .map((json) => Group.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Post>> fetchAllPosts() async {
    final result = await _client.read(
      urlPath: '/api/posts/',
      jsonHeaders: const {},
    );

    final List<dynamic> data = (result as List?) ?? const [];
    return data
        .map((json) => Post.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Comment>> fetchAllComments() async {
    final result = await _client.read(
      urlPath: '/api/comments/',
      jsonHeaders: const {},
    );

    final List<dynamic> data = (result as List?) ?? const [];
    return data
        .map((json) => Comment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Post> fetchPostById(int postId) async {
    final result = await _client.read(
      urlPath: '/api/posts/$postId/',
      jsonHeaders: const {},
    );

    if (result is Map<String, dynamic>) {
      return Post.fromJson(result);
    }

    throw Exception('Post not found');
  }

  @override
  Future<Post> createPostMultipart({
    required int groupId,
    required String title,
    required String body,
    required String emoji,
    String? feeling,
    required bool public,
    bool anonymous = false,
    List<String> imageFilePaths = const [],
  }) async {
    final payload = <String, dynamic>{
      'group': groupId,
      'title': title,
      'body': body,
      'emoji': emoji,
      if ((feeling ?? '').trim().isNotEmpty) 'feeling': feeling,
      'public': public,
      'anonymous': anonymous,
      'comments': <dynamic>[],
      'images': <dynamic>[],
    };

    final result = await _client.post(
      urlPath: '/api/posts/',
      jsonHeaders: const {},
      jsonPayload: payload,
      expectedStatusCode: 201,
    );

    return Post.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<Comment> addComment({
    required int postId,
    required String content,
    bool anonymous = false,
  }) async {
    final payload = <String, dynamic>{
      'post': postId,
      'content': content,
      'anonymous': anonymous,
      'user': anonymous ? 'Anonymous' : 'You',
      'author_id': 0,
      'author_username': anonymous ? 'Anonymous' : 'You',
      'pub_date': DateTime.now().toIso8601String(),
    };

    final result = await _client.post(
      urlPath: '/api/comments/',
      jsonHeaders: const {},
      jsonPayload: payload,
      expectedStatusCode: 201,
    );

    return Comment.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<Comment> addCommentMultipart({
    required int postId,
    required String content,
    bool anonymous = false,
    String? imageFilePath,
  }) async {
    return addComment(postId: postId, content: content, anonymous: anonymous);
  }
}
