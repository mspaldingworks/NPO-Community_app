import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:transconnect/features/community/models/group_model.dart';

class CommunityService {
  final String _baseUrl = 'http://api.lunashome.com/api';

  Future<List<Group>> fetchGroups() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/groups/'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Group.fromJson(json)).toList();
      } else {
        log('Failed to load groups. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load groups from API');
      }
    } catch (e) {
      log('An error occurred while fetching groups: $e');
      rethrow;
    }
  }
}
