import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/models/resource.dart';

class ResourceService extends ApiClient {

  final SharedPreferencesService _prefsService = SharedPreferencesService();
  
  // Fetches all resources.
  Future<List<Resource>> fetchResources() async {
    // 1. Await the result of the asynchronous shared preferences call.
    // The 'user_token' is now properly handled.
    String? token = _prefsService.getData('user_token');
    if (token == null) {
      throw Exception('Authentication token not found.');
    }
    // 2. Await the response from the API call.
    // The 'response' variable is now of type 'http.Response'.
    final response = await read(
      jsonHeaders: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      urlPath: 'api/resources/',
    );

    // 3. Check for a successful status code before trying to parse the body.
    if (response.statusCode == 200) {
      // 4. The response is now a valid http.Response object, so you can access its body.
      final List<Resource> resources = createResourceListFromJson(response.body);
      return resources;
    } else {
      // Handle the case where the server returns an error.
      throw Exception('Failed to load resources. Status code: ${response.statusCode}');
    }
  }

  List<Resource> createResourceListFromJson(String jsonBody) {
  // 1. Decode the JSON string into a list of dynamic maps.
  final List<dynamic> jsonList = jsonDecode(jsonBody);

  // 2. Map each dynamic map to a Resource object using the fromJson factory.
  // The .toList() method converts the iterable to a final list.
  return jsonList.map((json) => Resource.fromJson(json)).toList();
}

  // Adds a new resource.
  Future<void> addResource({
    required String name,
    required String description,
    String? website,
  }) async {
    // TODO: Implement with api.luxashome.com
  }
}
