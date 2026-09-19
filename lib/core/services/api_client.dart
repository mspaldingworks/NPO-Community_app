import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';

import 'package:npo_community/core/services/api_client_interface.dart';

/// A parent class for making generic API calls, now handling authentication
/// token retrieval and standardized response processing.
class ApiClient implements ApiClientInterface {
  final Logger _logger = Logger();
  @visibleForTesting
  static http.Client? debugHttpClientOverride;

  static const String _authTokenKey = 'user_token';
  final SharedPreferencesService _prefsService;

  ApiClient() : _prefsService = SharedPreferencesService();

  String get authToken {
    final token = _prefsService.getData(_authTokenKey);
    if (token == null) {
      throw const ApiClientException(
        'Authentication token not found. User is not logged in.',
      );
    }
    return token;
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Token $authToken',
  };

  @protected
  http.Client get httpClient => debugHttpClientOverride ?? http.Client();

  /// Processes the HTTP response, checks the status code, and decodes the body.
  /// Throws an Exception on failure or returns the decoded JSON/null on success.
  dynamic _processResponse(
    http.Response response, {
    int expectedStatusCode = 200,
  }) {
    if (response.statusCode == expectedStatusCode) {
      if (response.body.isNotEmpty) {
        try {
          return jsonDecode(response.body);
        } on FormatException {
          throw const ApiClientException(
            'The server returned an unreadable response. Please try again.',
          );
        }
      }
      return null; // For 204 No Content
    } else {
      final dynamic errorJson = tryDecodeJson(response.body);
      throw ApiClientException(
        extractErrorMessage(errorJson, response.statusCode),
      );
    }
  }

  Uri _buildUri(String urlPath) {
    final uri = AppConfig.current.apiUri(urlPath);
    _logger.i('Requesting URL: $uri');
    return uri;
  }

  @protected
  dynamic tryDecodeJson(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  @protected
  String extractErrorMessage(dynamic errorJson, int statusCode) {
    if (errorJson is Map) {
      final primaryMessage =
          firstErrorString(errorJson['detail']) ??
          firstErrorString(errorJson['error']) ??
          firstErrorString(errorJson['message']) ??
          firstErrorString(errorJson['non_field_errors']);
      if (primaryMessage != null) {
        return primaryMessage;
      }

      final fieldErrors = <String>[];
      errorJson.forEach((key, value) {
        final normalizedKey = key?.toString();
        if (normalizedKey == null ||
            normalizedKey == 'detail' ||
            normalizedKey == 'error' ||
            normalizedKey == 'message' ||
            normalizedKey == 'non_field_errors') {
          return;
        }

        final fieldMessage = firstErrorString(value);
        if (fieldMessage != null) {
          fieldErrors.add('${formatFieldName(normalizedKey)}: $fieldMessage');
        }
      });

      if (fieldErrors.isNotEmpty) {
        return fieldErrors.join('\n');
      }
    }

    final listMessage = firstErrorString(errorJson);
    if (listMessage != null) {
      return listMessage;
    }

    return 'Request failed with status code $statusCode.';
  }

  @protected
  String? firstErrorString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      final items = value
          .map(firstErrorString)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();
      if (items.isEmpty) {
        return null;
      }
      return items.join(', ');
    }
    return null;
  }

  @protected
  String formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @protected
  String networkErrorMessage(Uri uri) {
    return 'Unable to reach the Emerge Kentucky Alumni API at ${uri.origin}. '
        'Verify the server is running and that --dart-define=API_ORIGIN '
        'points to a host reachable from this device.';
  }

  /// Makes a POST request and processes the response.
  @override
  Future<dynamic> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('POST Requesting URL: $uri');
      final response = await httpClient.post(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      _logger.i('POST Response: ${response.statusCode}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw ApiClientException(networkErrorMessage(uri));
    } on http.ClientException {
      throw ApiClientException(networkErrorMessage(uri));
    } on TimeoutException {
      throw ApiClientException(networkErrorMessage(uri));
    } catch (_) {
      throw const ApiClientException(
        'The request could not be completed. Please try again.',
      );
    }
  }

  /// Makes a PUT request and processes the response.
  @override
  Future<dynamic> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('PUT Requesting URL: $uri');
      final response = await httpClient.put(
        uri,
        headers: jsonHeaders,
        body: jsonPayload != null ? jsonEncode(jsonPayload) : null,
      );
      _logger.i('PUT Response: ${response.statusCode}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw ApiClientException(networkErrorMessage(uri));
    } on http.ClientException {
      throw ApiClientException(networkErrorMessage(uri));
    } on TimeoutException {
      throw ApiClientException(networkErrorMessage(uri));
    } catch (_) {
      throw const ApiClientException(
        'The request could not be completed. Please try again.',
      );
    }
  }

  /// Makes a GET request and processes the response.
  @override
  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('GET Requesting URL: $uri');
      final response = await httpClient.get(uri, headers: jsonHeaders);
      _logger.i('GET Response: ${response.statusCode}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw ApiClientException(networkErrorMessage(uri));
    } on http.ClientException {
      throw ApiClientException(networkErrorMessage(uri));
    } on TimeoutException {
      throw ApiClientException(networkErrorMessage(uri));
    } catch (_) {
      throw const ApiClientException(
        'The request could not be completed. Please try again.',
      );
    }
  }

  /// Makes a PATCH request and processes the response.
  @override
  Future<dynamic> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('PATCH Requesting URL: $uri');
      final response = await httpClient.patch(
        uri,
        headers: jsonHeaders,
        body: jsonEncode(jsonPayload),
      );
      _logger.i('PATCH Response: ${response.statusCode}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw ApiClientException(networkErrorMessage(uri));
    } on http.ClientException {
      throw ApiClientException(networkErrorMessage(uri));
    } on TimeoutException {
      throw ApiClientException(networkErrorMessage(uri));
    } catch (_) {
      throw const ApiClientException(
        'The request could not be completed. Please try again.',
      );
    }
  }

  /// Makes a DELETE request and processes the response.
  @override
  Future<dynamic> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    int expectedStatusCode = 204,
  }) async {
    final uri = _buildUri(urlPath);
    try {
      _logger.i('DELETE Requesting URL: $uri');
      final response = await httpClient.delete(uri, headers: jsonHeaders);
      _logger.i('DELETE Response: ${response.statusCode}');
      return _processResponse(response, expectedStatusCode: expectedStatusCode);
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw ApiClientException(networkErrorMessage(uri));
    } on http.ClientException {
      throw ApiClientException(networkErrorMessage(uri));
    } on TimeoutException {
      throw ApiClientException(networkErrorMessage(uri));
    } catch (_) {
      throw const ApiClientException(
        'The request could not be completed. Please try again.',
      );
    }
  }
}

class ApiClientException implements Exception {
  final String message;

  const ApiClientException(this.message);

  @override
  String toString() => message;
}
