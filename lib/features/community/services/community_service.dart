import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:transconnect/features/community/models/group_model.dart';

class CommunityService {
  final String _baseUrl = 'http://54.243.117.197/api';

  Future<List<Group>> fetchGroups() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/groups/'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Group.fromJson(json)).toList();
      } else {
        log('Failed to load groups. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load groups');
      }
    } catch (e) {
      log('An error occurred while fetching groups: $e');
      throw Exception('An error occurred while fetching groups: $e');
    }
  }
}
