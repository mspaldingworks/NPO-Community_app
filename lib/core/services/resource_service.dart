// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/resource.dart';

class ResourceService extends ApiClient {
  
  ResourceService();

  // Helper function remains, though it will now work with the output 
  // of the ApiClient's response processing.
  List<Resource> createResourceListFromJson(dynamic jsonList) {
  final List<dynamic> decodedList = jsonList as List<dynamic>;
  return decodedList.map((json) => Resource.fromJson(json)).toList();
  }

  // Fetches all resources.
  Future<List<Resource>> fetchResources() async {
    final result = await read(
      jsonHeaders: authHeaders, // Uses inherited property
      urlPath: 'api/resources/',
    );

    return createResourceListFromJson(result);
  }

  // Adds a new resource.
  Future<Resource> addResource({
    required String name,
    required String description,
    required String type,
    String? website,
    String? phoneNumber,
    required List<String> tags,
  }) async {
    final result = await post(
      urlPath: 'api/resources/',
      jsonHeaders: authHeaders, // Uses inherited property
      jsonPayload: {
        'name': name,
        'description': description,
        'type': type,
        'url': website,
        'phone_number': phoneNumber,
        'tags': tags,
      },
      expectedStatusCode: 201, // Explicitly set expected status code for POST
    );
    return Resource.fromJson(result as Map<String, dynamic>);
  }

  // Updates an existing resource.
  Future<Resource> updateResource(Resource resource) async {
    final result = await put(
      urlPath: 'api/resources/${resource.id}/',
      jsonHeaders: authHeaders, // Uses inherited property
      jsonPayload: {
        'name': resource.name,
        'description': resource.description,
        'type': resource.type,
        'url': resource.url,
        'phone_number': resource.phoneNumber,
        'tags': resource.tags,
      },
    );
    return Resource.fromJson(result as Map<String, dynamic>);
  }

  // Deletes a resource.
  Future<void> deleteResource(int resourceId) async {
    await delete(
      urlPath: 'api/resources/$resourceId/',
      jsonHeaders: authHeaders, // Uses inherited property
    );
  }
}