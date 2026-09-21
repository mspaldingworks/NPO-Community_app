import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/config/public_config.dart';

class PublicConfigRepository {
  PublicConfigRepository({required this.config, required this.httpClient});

  final AppConfig config;
  final http.Client httpClient;

  Future<PublicConfig> fetch() async {
    if (!config.networkEnabled) {
      return PublicConfig.defaults();
    }

    final response = await httpClient.get(config.apiUri('/api/public-config/'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicConfig.fromJson(payload);
    }

    return PublicConfig.defaults();
  }
}
