import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:transconnect/core/config.dart';

/// A parent class for making generic API calls.
/// Other services can extend this class to inherit CRUD functionality.
class ApiClient {
  // Base URI for your API.
  // Example: 'https://api.myendpoint.com/v1'
  final String _baseUrl = AppConfig.baseUrl;  
  final Logger _logger = Logger();

  /// Builds the full URL for the API request by combining baseUri and urlPath.
  Uri _buildUri(String urlPath) {
    final path = urlPath.startsWith('/') ? urlPath.substring(1) : urlPath;
    final uri = Uri.parse('$_baseUrl/$path');
    _logger.i('Requesting URL: $uri');
    return uri;
  }

  /// Makes a POST request to create a new resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users').
  /// - `jsonHeaders`: A map of headers, typically including 'Content-Type': 'application/json'.
  /// - `jsonPayload`: The data to be sent in the request body.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
  }) async {
    final uri = _buildUri(urlPath);    
    try {
      _logger.i('POST Requesting URL: $uri');
      final response = await http.post(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      _logger.i('POST Response: ${response.statusCode} ${response.body}');
      return response;
    } catch (e) {
      throw Exception('Failed to create resource: $e');
    }
  }

  /// Makes a PUT request to update a resource.
  ///
  /// Parameters:
  /// - `urlPath`: The specific endpoint path (e.g., 'users/123').
  /// - `jsonHeaders`: A map of headers.
  /// - `jsonPayload`: The data to be updated in the request body.
  ///
  /// Returns a `http.Response` on success or throws an `Exception` on error.
  Future<http.Response> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
  }) async {
    final url = _buildUri(urlPath);
    _logger.i('PUT Requesting URL: $url');

    final response = await http.put(
      url,
      headers: jsonHeaders,
      body: jsonPayload != null ? jsonEncode(jsonPayload) : null,
    );

    _logger.i('PUT Response: ${response.statusCode} ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw Exception('Failed to put data. Status code: ${response.statusCode}');
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
    Map<String, String>? jsonHeaders,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('GET Requesting URL: $uri');
      final response = await http.get(
        uri,
        headers: jsonHeaders,
      );
      _logger.i('GET Response: ${response.statusCode} ${response.body}');
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
      _logger.i('PATCH Requesting URL: $uri');
      final response = await http.patch(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      _logger.i('PATCH Response: ${response.statusCode} ${response.body}');
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
      _logger.i('DELETE Requesting URL: $uri');
      final response = await http.delete(
        uri,
        headers: jsonHeaders,
      );
      _logger.i('DELETE Response: ${response.statusCode} ${response.body}');
      return response;
    } catch (e) {
      throw Exception('Failed to delete resource: $e');
    }
  }
}