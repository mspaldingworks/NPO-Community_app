import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:transconnect/features/community/models/group_model.dart';

class CommunityService {
  final String _apiUrl = 'https://api.luxeahome.com/api/groups/';
  final String _token = '0c12ae0d159bdd154d80a8aead755e5a1c2afe80'; // Maddie's new token

  Future<List<Group>> fetchGroups() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Group.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load groups');
      }
    } catch (e) {
      throw Exception('Error fetching groups: $e');
    }
  }
}
