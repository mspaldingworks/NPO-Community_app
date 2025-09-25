// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

/// A parent class for making generic API calls, now handling authentication 
/// token retrieval and standardized response processing.
class ApiClient {
  final String _baseUrl = 'https://api.luxashome.com';
  final Logger _logger = Logger();
  
  static const String _authTokenKey = 'user_token'; 
  final SharedPreferencesService _prefsService; 

  ApiClient() : _prefsService = SharedPreferencesService(); 
  
  String get authToken {
    final token = _prefsService.getData(_authTokenKey);
    if (token == null) {
      throw Exception('Authentication token not found. User is not logged in.');
    }
    return token;
  }
  
  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Token $authToken',
  };

  /// Processes the HTTP response, checks the status code, and decodes the body.
  /// Throws an Exception on failure or returns the decoded JSON/null on success.
  dynamic _processResponse(http.Response response, {int expectedStatusCode = 200}) {
    if (response.statusCode == expectedStatusCode) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null; // For 204 No Content
    } else {
      String errorMessage = 'API Error: Status ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson.containsKey('detail')) {
          errorMessage = errorJson['detail'] as String;
        }
      } catch (_) {
        // Body wasn't JSON or didn't have 'detail'
      }
      throw Exception(errorMessage);
    }
  }

  Uri _buildUri(String urlPath) {
    final path = urlPath.startsWith('/') ? urlPath.substring(1) : urlPath;
    final uri = Uri.parse('$_baseUrl/$path');
    _logger.i('Requesting URL: $uri');
    return uri;
  }

  /// Makes a POST request and processes the response.
  Future<dynamic> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
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
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } catch (e) {
      // Re-throw the specific exception from _processResponse or original Exception
      throw Exception('Failed to create resource: $e');
    }
  }

  /// Makes a PUT request and processes the response.
  Future<dynamic> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('PUT Requesting URL: $uri');
      final response = await http.put(
        uri,
        headers: jsonHeaders,
        body: jsonPayload != null ? jsonEncode(jsonPayload) : null,
      );
      _logger.i('PUT Response: ${response.statusCode} ${response.body}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } catch (e) {
      throw Exception('Failed to put data: $e');
    }
  }

  /// Makes a GET request and processes the response.
  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('GET Requesting URL: $uri');
      final response = await http.get(
        uri,
        headers: jsonHeaders,
      );
      _logger.i('GET Response: ${response.statusCode} ${response.body}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } catch (e) {
      throw Exception('Failed to read resource: $e');
    }
  }

  /// Makes a PATCH request and processes the response.
  Future<dynamic> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
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
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } catch (e) {
      throw Exception('Failed to update resource: $e');
    }
  }

  /// Makes a DELETE request and processes the response.
  Future<dynamic> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    int expectedStatusCode = 204,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('DELETE Requesting URL: $uri');
      final response = await http.delete(
        uri,
        headers: jsonHeaders,
      );
      _logger.i('DELETE Response: ${response.statusCode} ${response.body}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } catch (e) {
      throw Exception('Failed to delete resource: $e');
    }
  }
}