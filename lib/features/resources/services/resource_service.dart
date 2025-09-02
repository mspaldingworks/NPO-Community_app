import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:transconnect/features/resources/models/issue.dart';
import 'package:transconnect/features/resources/models/messaging_guide.dart';
import 'package:transconnect/features/resources/models/resource.dart';

class ResourceService {
  final String _baseUrl = 'http://api.lunashome.com/api';

  Future<List<Resource>> fetchResources() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/resources/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Resource.fromJson(json)).toList();
      } else {
        log('Failed to load resources. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load resources');
      }
    } catch (e) {
      log('An error occurred while fetching resources: $e');
      rethrow;
    }
  }

  Future<List<MessagingGuide>> fetchMessagingGuides() async {
    try {
      final response =
      await http.get(Uri.parse('$_baseUrl/messaging-guides/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MessagingGuide.fromJson(json)).toList();
      } else {
        log('Failed to load messaging guides. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load messaging guides');
      }
    } catch (e) {
      log('An error occurred while fetching messaging guides: $e');
      rethrow;
    }
  }

  Future<List<Issue>> fetchIssues() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/issues/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Issue.fromJson(json)).toList();
      } else {
        log('Failed to load issues. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Failed to load issues');
      }
    } catch (e) {
      log('An error occurred while fetching issues: $e');
      rethrow;
    }
  }
}