import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/config/public_config.dart';

abstract interface class PublicConfigSource {
  Future<PublicConfig> fetch();
}

class DemoPublicConfigSource implements PublicConfigSource {
  const DemoPublicConfigSource();

  @override
  Future<PublicConfig> fetch() async => PublicConfig.defaults();
}

class HttpPublicConfigSource implements PublicConfigSource {
  HttpPublicConfigSource({required this.config});

  final AppConfig config;

  @override
  Future<PublicConfig> fetch() async {
    try {
      final response = await http.get(config.apiUri('/api/public-config/'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return PublicConfig.fromJson(payload);
      }
    } catch (_) {
      return PublicConfig.defaults();
    }

    return PublicConfig.defaults();
  }
}
