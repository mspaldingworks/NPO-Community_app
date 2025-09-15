import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/models/post.dart';

class CommunityService extends ApiClient {
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  Future<List<Post>> fetchPosts() async {
    try {
      String? token = _prefsService.getData('user_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await read(
        urlPath: 'api/posts/', 
        jsonHeaders: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        log('Failed to load posts. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load posts');
      }
    } catch (e) {
      log('An error occurred while fetching posts: $e');
      throw Exception('An error occurred while fetching posts: $e');
    }
  }
}
