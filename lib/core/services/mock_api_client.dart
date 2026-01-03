import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:transconnect/core/services/api_client_interface.dart';

class MockApiClient implements ApiClientInterface {
  final Logger _logger = Logger();

  final Map<String, List<dynamic>> _cache = {};

  String _normalizePath(String urlPath) {
    var p = urlPath.trim();
    if (p.isEmpty) return p;

    final queryIndex = p.indexOf('?');
    if (queryIndex >= 0) {
      p = p.substring(0, queryIndex);
    }

    while (p.startsWith('/')) {
      p = p.substring(1);
    }

    if (p.toLowerCase().startsWith('api/')) {
      p = p.substring(4);
    }

    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    if (p == 'groups') return 'group';
    if (p.startsWith('groups/')) return p.replaceFirst('groups/', 'group/');

    return p;
  }

  Future<String> _loadJsonFromAssets(String filePath) async {
    return await rootBundle.loadString(filePath);
  }

  Future<List<dynamic>> _readJsonFile(String urlPath) async {
    final cached = _cache[urlPath];
    if (cached != null) {
      return List<dynamic>.from(cached);
    }

    final path = 'lib/data/$urlPath.json';
    _logger.i('Reading from mock data file: $path');
    try {
      final jsonString = await _loadJsonFromAssets(path);
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        _cache[urlPath] = List<dynamic>.from(decoded);
        return List<dynamic>.from(decoded);
      }
      _cache[urlPath] = <dynamic>[];
      return <dynamic>[];
    } catch (e) {
      _logger.e('Error reading mock data file: $path');
      _cache[urlPath] = <dynamic>[];
      return [];
    }
  }

  Future<void> _writeJsonFile(String urlPath, List<dynamic> data) async {
    _cache[urlPath] = List<dynamic>.from(data);
    final path = 'lib/data/$urlPath.json';
    _logger.i('Writing to mock data file: $path');
    try {
      final file = File(path);
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      _logger.e('Error writing mock data file: $path');
    }
  }

  @override
  Future<dynamic> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 201,
  }) async {
    final normalized = _normalizePath(urlPath);
    final resource = normalized.contains('/') ? normalized.split('/').first : normalized;
    final data = await _readJsonFile(resource);
    final newId = data.isNotEmpty ? data.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1 : 1;
    jsonPayload['id'] = newId;
    data.add(jsonPayload);
    await _writeJsonFile(resource, data);
    return jsonPayload;
  }

  @override
  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  }) async {
    final normalized = _normalizePath(urlPath);
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      final resource = parts[0];
      final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (id != null) {
        final data = await _readJsonFile(resource);
        return data.firstWhere((element) => element['id'] == id, orElse: () => null);
      }
      return await _readJsonFile(resource);
    }
    return await _readJsonFile(normalized);
  }

  @override
  Future<dynamic> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final normalized = _normalizePath(urlPath);
    final parts = normalized.split('/');
    final resource = parts[0];
    final id = int.parse(parts[1]);
    final data = await _readJsonFile(resource);
    final index = data.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      data[index] = jsonPayload;
      await _writeJsonFile(resource, data);
      return jsonPayload;
    }
    return null;
  }

  @override
  Future<dynamic> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final normalized = _normalizePath(urlPath);
    final parts = normalized.split('/');
    final resource = parts[0];
    final id = int.parse(parts[1]);
    final data = await _readJsonFile(resource);
    final index = data.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final existingItem = data[index] as Map<String, dynamic>;
      existingItem.addAll(jsonPayload);
      data[index] = existingItem;
      await _writeJsonFile(resource, data);
      return existingItem;
    }
    return null;
  }

  @override
  Future<dynamic> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    int expectedStatusCode = 204,
  }) async {
    final normalized = _normalizePath(urlPath);
    final parts = normalized.split('/');
    final resource = parts[0];
    final id = int.parse(parts[1]);
    final data = await _readJsonFile(resource);
    data.removeWhere((element) => element['id'] == id);
    await _writeJsonFile(resource, data);
    return null;
  }
}
