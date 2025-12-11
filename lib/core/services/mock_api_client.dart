import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:transconnect/core/services/api_client_interface.dart';

class MockApiClient implements ApiClientInterface {
  final Logger _logger = Logger();

  Future<String> _loadJsonFromAssets(String filePath) async {
    return await rootBundle.loadString(filePath);
  }

  Future<List<dynamic>> _readJsonFile(String urlPath) async {
    final path = 'lib/data/$urlPath.json';
    _logger.i('Reading from mock data file: $path');
    try {
      final jsonString = await _loadJsonFromAssets(path);
      return jsonDecode(jsonString);
    } catch (e) {
      _logger.e('Error reading mock data file: $path');
      return [];
    }
  }

  Future<void> _writeJsonFile(String urlPath, List<dynamic> data) async {
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
    final data = await _readJsonFile(urlPath);
    final newId = data.isNotEmpty ? data.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1 : 1;
    jsonPayload['id'] = newId;
    data.add(jsonPayload);
    await _writeJsonFile(urlPath, data);
    return jsonPayload;
  }

  @override
  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  }) async {
    if (urlPath.contains('/')) {
      final parts = urlPath.split('/');
      final resource = parts[0];
      final id = int.tryParse(parts[1]);
      if (id != null) {
        final data = await _readJsonFile(resource);
        return data.firstWhere((element) => element['id'] == id, orElse: () => null);
      }
    }
    return await _readJsonFile(urlPath);
  }

  @override
  Future<dynamic> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
    int expectedStatusCode = 200,
  }) async {
    final parts = urlPath.split('/');
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
    final parts = urlPath.split('/');
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
    final parts = urlPath.split('/');
    final resource = parts[0];
    final id = int.parse(parts[1]);
    final data = await _readJsonFile(resource);
    data.removeWhere((element) => element['id'] == id);
    await _writeJsonFile(resource, data);
    return null;
  }
}
