import 'dart:convert';
import 'package:http/http.dart' as http;


/// A parent class for making generic API calls.
/// Other services can extend this class to inherit CRUD functionality.
class ApiClient {
  // Base URI for your API.
  // Example: 'https://api.myendpoint.com/v1'
  final String baseUri = 'http://api.luxashome.com';  

  /// Builds the full URL for the API request by combining baseUri and urlPath.
  Uri _buildUri(String urlPath) {
    return Uri.parse('$baseUri/$urlPath');
  }

  /// Makes a POST request to create a new resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users').
  /// - `jsonHeaders`: A map of headers, typically including 'Content-Type': 'application/json'.
  /// - `jsonPayload`: The data to be sent in the request body.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> create({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
  }) async {
    final uri = _buildUri(urlPath);    
    try {
      final response = await http.post(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to create resource: $e');
    }
  }

  /// Makes a GET request to read a resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users/123').
  /// - `jsonHeaders`: A map of headers for the request.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> read({
    required String urlPath,
    required Map<String, String> jsonHeaders,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      final response = await http.get(
        uri,
        headers: jsonHeaders,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to read resource: $e');
    }
  }

  /// Makes a PATCH request to update a resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users/123').
  /// - `jsonHeaders`: A map of headers.
  /// - `jsonPayload`: The data to be updated in the request body.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      final response = await http.patch(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to update resource: $e');
    }
  }

  /// Makes a DELETE request to delete a resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users/123').
  /// - `jsonHeaders`: A map of headers.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      final response = await http.delete(
        uri,
        headers: jsonHeaders,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to delete resource: $e');
    }
  }
}